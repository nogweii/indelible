module Indelible
  # TODO: conflicts when filename already exists (note starts the same way)
  class SyncBackend
    def initialize(email, password, path)
      @email      = email
      @password   = password
      @poll_freq  = 1200    # 20 minutes
      @path       = path
      @index      = load_index
      @simplenote = SimpleNote.new
      @simplenote.login @email, @password
    end

    def update_local_index
      @index.notes.each do |key, note|
        if note['status'] == 'in_sync' &&
            !File.exist?(note['path'])
          @index.remove_note key
        end
      end

      @index.update_hashes
    end

    def make_remote_index_manageable(remote_index)
      new_index = {}
      remote_index.each do |note|
        new_index[note['key']] = { 'modify' => note['modify'],
          'deleted' => note['deleted'] }
      end
      new_index
    end

    def run
      loop do
        sync
        sleep @poll_freq
      end
    end

    # TODO: make more clever and efficient
    def sync
      remote_index = make_remote_index_manageable @simplenote.get_index
      update_local_index
      update_timestamps = []

      diff = @index.diff remote_index

      diff[:push].each do |key|
        note = @index.retrieve_note key
        contents = open(note['path']).read
        @simplenote.update_note key, contents
        update_timestamps << key
      end

      diff[:retrieve].each do |key|
        begin
          note = @simplenote.get_note(key).to_s
          filename = get_filename note
          open(filename, 'w') { |f| f << note }
          modified = remote_index[key]['modify']
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

      Dir.glob(File.join(@path, "*.txt")).each do |file|
        next if file =~ /~$/
        if !@index.note_path_exists?(file)
          puts "Creating #{file}"
          key = @simplenote.create_note(open(file).read).to_s
          update_timestamps << key
          @index.store_note key, modified, file
        end
      end

      # Update timestamps
      if !update_timestamps.empty?
        remote_index = make_remote_index_manageable @simplenote.get_index
        update_timestamps.each do |key|
          note = @index.retrieve_note key
          @index.store_note key, remote_index[key]['modify'], note['path']
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
      Index.create!(@path) if !File.exists?(@path)
      Index.new @path
    end
  end
end
