module Indelible
  class Index
    FILENAME   = ".indelible".freeze
    BASE_INDEX = { 'created' => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
                   'last_synced' => nil, 'notes' => {}, 'hashes' => {},
                   'paths'   => {} }.freeze
    STATES     = ['delete_local', 'delete_remote',  'update_local',
                  'update_remote', 'create', 'in_sync',
                  'deleted']

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
      hash = Digest::MD5.hexdigest(File.open(path).read).to_s
      @state['paths'][path] = note_id
      @state['notes'][note_id] = { 'modified' => modified,
                                   'path' => path,
                                   'status' => 'in_sync' }
      @state['hashes'][note_id] = hash
      nil
    end

    def remove_note(note_id)
      @dirty = true
      @state['notes'][note_id]['status'] = 'delete_remote'
      nil
    end

    def remove_notes(note_id_list)
      note_id_list.each { |note_id| remove_note note_id }
    end

    def purge_note(note_id)
      @dirty = true
      @state['notes'][note_id]['status'] = 'deleted'
      @state['notes'][note_id]['modified'] = Time.now.strftime "%Y-%m-%d %H:%M:%S"
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
      # Checks whether a note previously added to the local index
      # has been remotely deleted.
      deleted = remote_index.select do |key, remote|
        if local = @state['notes'][key] && remote['deleted']
          local_mod  = Time.parse @state['notes'][key]['modified']
          remote_mod = Time.parse remote['modify']
          local_mod > remote_mod
        end
      end.tap do |notes|
        notes.each do |note|
          @state['notes'][note['key']]['status'] = 'delete_local'
          @state['notes'][note['key']]['modified'] = note['modify']
        end
      end.map { |key, remote| key }

      # At this point, remote deletes don't matter anymore. Remove
      # them.
      remote_index.delete_if { |k, n| n['deleted'] }

      new_or_existing = remote_index.keys - deleted
      # Everything that is not in this index and not deleted is probably
      # new.
      new_notes = new_or_existing.select { |key|
        !(@state['notes'].has_key?(key))
      }

      should_retrieve = new_notes
      existing = new_or_existing - new_notes

      should_retrieve += existing.select do |key|
        local = @state['notes'][key]
        local_mod  = Time.parse @state['notes'][key]['modified']
        remote_mod = Time.parse remote_index[key]['modify']
        local_mod < remote_mod
      end.tap { |notes| notes.each { |key|
          @state['notes'][key]['status'] = 'update_local'
        }
      }

      remove_remote = find_removed_from_disk new_or_existing

      should_push = @state['notes'].select { |key, note|
        note['status'] == 'update_remote'
      }.map { |key, note| key }

      { :retrieve => should_retrieve, :push => should_push,
        :remove_remote => remove_remote, :remove_local => deleted }
    end

    def find_removed_from_disk(remote_index)
      @state['notes'].select do |note_id, note|
        removed = !File.exist?(note['path'])
        if removed
          note['status'] = 'delete_remote'
          if remote = remote_index.find { |n| n['key'] == note_id }
            local_mod = Time.parse note['modified']
            remote_mod = Time.parse remote['modify']

            removed = removed && (remote_mod < local_mod)
          end
        end
        removed
      end.map { |note_id, note| note_id }
    end

    def self.create!(path)
      File.open(path, 'w') { |f| f << BASE_INDEX.to_json }
    end

    def self.exists?(path)
      File.exist?(path)
    end

    def update_hashes
      @state['notes'].each do |key, note|
        if note['status'] != 'delete_remote'
          new_hash = Digest::MD5.hexdigest(File.open(note['path']).read).to_s
          if @state['hashes'][key] != new_hash
            note['status'] = 'update_remote'
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
