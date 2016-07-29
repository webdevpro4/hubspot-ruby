require 'hubspot/utils'

module Hubspot
  #
  # HubSpot Engagements API
  #
  # {http://developers.hubspot.com/docs/methods/engagements/create_engagement}
  #
  class Engagement
    CREATE_ENGAGMEMENT_PATH = '/engagements/v1/engagements'
    ENGAGEMENT_PATH = '/engagements/v1/engagements/:engagement_id'

    attr_reader :id
    attr_reader :engagement
    attr_reader :associations
    attr_reader :metadata

    def initialize(response_hash)

      @engagement = response_hash["engagement"]
      @associations = response_hash["associations"]
      @metadata = response_hash["metadata"]
      @id = engagement["id"]
    end

    class << self
      def create!(params={})
        response = Hubspot::Connection.post_json(CREATE_ENGAGMEMENT_PATH, params: {}, body: params )
        new(HashWithIndifferentAccess.new(response))
      end

      def find(engagement_id)
        begin
          response = Hubspot::Connection.get_json(ENGAGEMENT_PATH, { engagement_id: engagement_id })
          new(HashWithIndifferentAccess.new(response))
        rescue Hubspot::RequestError => ex
          if ex.response.code == 404
            return nil
          else
            raise ex
          end
        end
      end
    end

    # Archives the engagement in hubspot
    # {http://developers.hubspot.com/docs/methods/engagements/delete-engagement}
    # @return [TrueClass] true
    def destroy!
      Hubspot::Connection.delete_json(ENGAGEMENT_PATH, {engagement_id: id})
      @destroyed = true
    end

    def destroyed?
      !!@destroyed
    end

    def [](property)
      @properties[property]
    end

    # Updates the properties of an engagement
    # {http://developers.hubspot.com/docs/methods/engagements/update_engagement}
    # @param params [Hash] hash of properties to update
    # @return [Hubspot::Engagement] self
    def update!(params)
      data = {
        engagement: engagement,
        associations: associations,
        metadata: metadata
      }

      Hubspot::Connection.put_json(ENGAGEMENT_PATH, params: { engagement_id: id }, body: data)
      self
    end
  end

  class EngagementNote < Engagement
    def body
      metadata['body']
    end

    def contact_ids
      associations['contactIds']
    end

    class << self
      def create!(contact_id, note_body, owner_id = nil)
        data = {
          engagement: {
            type: 'NOTE'
          },
          associations: {
            contactIds: [contact_id]
          },
          metadata: {
            body: note_body
          }
        }

        # if the owner id has been provided, append it to the engagement
        data[:engagement][:owner_id] = owner_id if owner_id

        super(data)
      end
    end
  end
end
