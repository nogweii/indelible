require 'pp'
module ZenNote
  # TODO: conflicts when filename already exists (note starts the same way)
  class SyncBackend
    def initialize(email, password, path)
      @email      = email
      @password   = password
      @poll_freq  = 20
      @path       = path
      @index      = load_index
      @simplenote = SimpleNote.new
      @simplenote.login @email, @password
    end

    def update_local_index
      @index.notes.each do |key, note|
        if note['status'] == 'synced' &&
            !File.exist?(note['path'])
          @index.remove_note key
        end
      end
      
      @index.update_hashes
    end

    # TODO: make more clever and efficient
    def sync
      remote_index = @simplenote.get_index
      update_local_index
      
      diff = @index.diff remote_index
      
      pp diff
      
      diff[:push].each do |key|
        note = @index.retrieve_note key
        contents = open(note['path']).read
        puts "updating #{key}"
        @simplenote.update_note key, contents
      end
      
      diff[:retrieve].each do |key|
        begin
          note = @simplenote.get_note(key).to_s
          filename = get_filename note
          open(filename, 'w') { |f| f << note }
          modified = remote_index.find { |n| n['key'] }['modify']
          puts "Retrieving #{key}"
          @index.store_note key, modified, filename
        rescue
          raise
        end
      end

      diff[:remove_remote].each do |key|
        @simplenote.delete_note key
      end

      diff[:remove_local].each do |key|
        note = @index.retrieve_note key
        if note
          File.delete note['path']
          @index.purge_note key
        end
      end

      Dir.glob(File.join(@path, "*")).each do |file|
        if !@index.note_path_exists?(file)
          puts "creating #{file}"
          key = @simplenote.create_note(open(file).read).to_s
          modified = Time.now.strftime '%Y-%m-%d %H:%M:%S'
          @index.store_note key, modified, file
        end
      end

      @index.save_state
    end

    def get_filename(note)
      name = note.split("\n")[0].gsub(/\s+/, '-').gsub(/\//, '').downcase + ".txt"
      File.join @path, name
    end

    private
    def load_index
      Index.create!(@path) if !Index.exists?(@path)
      Index.new @path
    end
  end
end
