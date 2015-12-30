module Hubspot
  class Utils
    class << self
      # Parses the hubspot properties format into a key-value hash
      def properties_to_hash(props)
        newprops = HashWithIndifferentAccess.new
        props.each { |k, v| newprops[k] = v["value"] }
        newprops
      end

      # Turns a hash into the hubspot properties format
      def hash_to_properties(hash, opts = {})
        key_name = opts[:key_name] || "property"
        hash.map { |k, v| { key_name => k.to_s, "value" => v } }
      end

      def dump_properties(hapikey=ENV['HUBSPOT_API_KEY'], filter={})
        with_hapikey(hapikey) do
          { 'groups'     => Hubspot::ContactProperties.groups({}, filter),
            'properties' => Hubspot::ContactProperties.all({}, filter).select { |p| !p['hubspotDefined'] }
          }
        end
      end

      def restore_properties(hapikey=ENV['HUPSPOT_API_KEY'], properties={}, dry_run=false)
        existing_properties                       = dump_properties(hapikey)
        skip, new_groups, new_props, update_props = compare_property_lists(properties, existing_properties)
        puts '','Skipping'
        skip.each { |h| puts "#{h[:reason]} - #{h[:prop]['groupName']}:#{h[:prop]['name']}" }
        with_hapikey(hapikey) do
          create_groups new_groups, dry_run
          create_properties new_props, dry_run
          update_properties update_props, dry_run
        end
      end

      def create_groups(groups, dry_run=false)
        puts '','Creating new groups'
        groups.each do |g|
          if dry_run || ContactProperties.create_group!(g)
            puts "Created: #{g['name']}"
          else
            puts "Failed: #{g['name']}"
          end
        end
      end

      def create_properties(props, dry_run=false)
        puts '','Creating new properties'
        props.each do |p|
          if dry_run || ContactProperties.create!(p)
            puts "Created: #{p['groupName']}:#{p['name']}"
          else
            puts "Failed: #{p['groupName']}:#{p['name']}"
          end
        end
      end

      def update_properties(props, dry_run=false)
        puts '','Updating existing properties'
        props.each do |p|
          if dry_run || ContactProperties.update!(p['name'], p)
            puts "Updated: #{p['groupName']}:#{p['name']}"
          else
            puts "Failed: #{p['groupName']}:#{p['name']}"
          end
        end
      end

      def compare_property_lists(source, target)
        skip         = [] # Array of skipped properties and the reason
        new_groups   = Set.new # Array of groups to create
        new_props    = [] # Array of properties to add
        update_props = [] # Array of properties to update
        src_groups   = source['groups']
        dst_groups   = target['groups']
        src_props    = source['properties']
        dst_props    = target['properties']

        src_props.each do |src|
          group = find_by_name(src['groupName'], src_groups)
          if src['createdUserId'].blank? then
            skip << { prop: src, reason: 'Not user created' }
          else
            dst = find_by_name(src['name'], dst_props)
            if dst
              if dst['readOnlyDefinition']
                skip << { prop: src, reason: 'Definition is read-only' }
              elsif ContactProperties.same?(src, dst)
                skip << { prop: src, reason: 'No change' }
              else
                new_groups << group unless find_by_name(group['name'], dst_groups)
                update_props << src
              end
            else
              new_groups << group unless find_by_name(group['name'], dst_groups)
              new_props << src
            end
          end
        end
        [skip, new_groups.to_a, new_props, update_props]
      end

      def with_hapikey(hapikey)
        begin
          Hubspot.configure(hapikey: hapikey) unless hapikey.blank?
          yield if block_given?
        ensure
          Hubspot.configure(hapikey: ENV['HUBSPOT_API_KEY']) unless hapikey.blank?
        end
      end

      private

      def find_by_name(name, set)
        set.detect { |item| item['name'] == name }
      end

    end
  end
end
