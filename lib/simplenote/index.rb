module ZenNote
    # TODO: use hash to determine a file already exists if simplenote
  # doesn't take care of that already, and deal with renames.
  # Index should be searchable as well, without resorting to API calls.
  class Index
    FILENAME   = ".zennote".freeze
    BASE_STATE = { 'created' => Time.now, 'last_synced' => nil,
                   'count' => 0, 'notes' => {},
                   'hashes'  => {},
                   'paths'   => {} }.freeze

    def initialize(path=nil)
      @path  = File.join(path, FILENAME)
      @state = load
      @dirty = false
    end

    def notes
      @state['notes']
    end

    def note_path_exists?(path)
      @state['paths'].has_key? path
    end

    def note_exists?(note_id)
      @state['notes'].has_key? note_id
    end

    def store_note(note_id, modified, path)
      @dirty = true
      hash = MD5.md5(File.open(path).read).to_s
      @state['paths'][path] = note_id
      @state['notes'][note_id] = { 'modified' => modified,
                                   'path' => path,
                                   'status' => 'synced' }
      @state['hashes'][note_id] = hash
      nil
    end

    def remove_note(note_id)
      @dirty = true
      @state['notes'][note_id]['status'] = 'local_delete'
      nil
    end

    def remove_notes(note_id_list)
      note_id_list.each { |note_id| remove_note note_id }
    end

    def purge_note(note_id)
      @dirty = true
      @state['paths'].delete note_id
      @state['notes'].delete note_id
      @state['hashes'].delete note_id
      nil
    end

    def save_state
      if @dirty
        File.open(@path, 'w') { |f|
          f << @state.to_json
        }
        @dirty = false
      end
    end

    def retrieve_note(note_id)
      @state['notes'][note_id]
    end

    def get_local_path(note_id)
      retrieve_note['path']
    end

    # Seeks out differences between SimpleNote server and local index.
    # Returns list of keys that should be retrieved, removed remotely
    # and removed locally
    def diff(remote_index)
      should_retrieve = []

      remote_index.each do |note|
        if note['deleted'] == false &&
            (!@state['notes'][note['key']] ||
            @state['notes'][note['key']]['modified'] != note['modify'])
          should_retrieve << note['key']
        end
      end

      remove_remote = find_removed_from_disk
      remove_locally = remote_index.select { |n|
        n['deleted']
      }.map { |n| n['key'] }
      should_push = @state['notes'].select { |key, note|
        note['status'] == 'sync_pending'
      }.map { |key, note| key }

      { :retrieve => should_retrieve, :push => should_push,
        :remove_remote => remove_remote, :remove_local => remove_locally }
    end

    def find_removed_from_disk
      @state['notes'].select { |note_id, note|
        note['status'] == 'local_delete'
      }.map { |note_id, note| note_id }
    end

    def self.create!(path)
      File.open(path, 'w') { |f| f << BASE_STATE.to_json }
    end

    def self.exists?(path)
      File.exist?(path)
    end

    def update_hashes
      @state['notes'].each do |key, note|
        if note['status'] != 'local_delete'
          new_hash = MD5.md5 File.open(note['path']).read
          if @state['hashes'][key] != new_hash
            note['status'] = 'sync_pending'
          end
        end
      end
      @dirty = true # let's assume this always stains the index, 'cause
                    # we're some write-a-lots
    end

    def load
      Index.create!(@path) if !Index.exists?(@path)
      JSON.load(File.open(@path))
    end
  end
end
