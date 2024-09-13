require 'open-uri'
require 'base64'
require 'json'

module Klaviyo
  class KlaviyoError < StandardError; end

  class Client
    def initialize(api_key, url = 'https://a.klaviyo.com/')
      @api_key = api_key
      @url = url
    end

    def track(event, kwargs = {})
      defaults = {:id => nil, :email => nil, :properties => {}, :customer_properties => {}, :time => nil}
      kwargs = defaults.merge(kwargs)

      if kwargs[:email].to_s.empty? and kwargs[:id].to_s.empty?
        raise KlaviyoError.new('You must identify a user by email or ID')
      end

      customer_properties = kwargs[:customer_properties]
      customer_properties[:email] = kwargs[:email] unless kwargs[:email].to_s.empty?
      customer_properties[:id] = kwargs[:id] unless kwargs[:id].to_s.empty?

      time = kwargs[:time].strftime("%FT%T%z") if kwargs[:time]
      value = kwargs[:properties]["value"] || 0

      payload = {
        :data => {
          :type => 'event',
          :attributes => {
            "properties" => kwargs[:properties], 
            "time" => time, 
            "value" => value, 
            "value_currency" => "USD", 
            "metric" => {"data"=>{"type"=>"metric", "attributes"=>{"name"=>event}}},
            "profile" => {"data"=>{"type"=>"profile", "attributes"=>customer_properties}}
          }
        }
      }

      RestClient.post("#{@url}api/events", payload.to_json, {accept: :json, revision: '2024-02-15', content_type: :json, authorization: "Klaviyo-API-Key #{@api_key}"}) do |response, request, result, &block|
        if response.code == 202
          return true
        else
          raise KlaviyoError.new(JSON.parse(response))
        end
      end
    end

    def track_once(event, opts = {})
      opts.update('__track_once__' => true)
      track(event, opts)
    end

    def identify(base_attributes = {}, custom_properties = {})
      if base_attributes["email"].to_s.empty?
        raise KlaviyoError.new('You must identify a user by email or ID')
      end

      payload = {
        :data => {
          :type => 'profile',
          :attributes => {
            "email" => base_attributes["email"],
            "phone_number" => base_attributes["phone_number"],
            "first_name" => base_attributes["first_name"],
            "last_name" => base_attributes["last_name"],
            "location" => base_attributes["location"],
            "properties" => custom_properties
          }
        } 
      }
      
      RestClient.post("#{@url}api/profile-import", payload.to_json, {accept: :json, revision: '2024-02-15', content_type: :json, authorization: "Klaviyo-API-Key #{@api_key}"}) do |response, request, result, &block|
        if response.code == 200 || response.code == 201
          JSON.parse(response)
        else
          raise KlaviyoError.new(JSON.parse(response))
        end
      end
    end

    def lists
      RestClient.get("#{@url}api/lists", {accept: :json, revision: '2024-02-15', authorization: "Klaviyo-API-Key #{@api_key}"}) do |response, request, result, &block|
        if response.code == 200
          JSON.parse(response)
        else
          raise KlaviyoError.new(response)
        end
      end
    end

    def add_to_sms_list(phone, email, list_id)
      payload = {
        :data => {
          :type => 'profile-subscription-bulk-create-job',
          :attributes => {
            :profiles => {
              :data => [{
                :type => 'profile',
                :attributes => {"email" => email, "phone_number" => phone},
                :subscriptions => {
                  :sms => {
                    :marketing => {
                      :consent => "SUBSCRIBED"
                    }
                  }
                }
              }]
            }
          },
          :relationships => {
            :list => {
              :data => {
                :type => 'list',
                "id" => list_id
              }
            }
          }
        }
      }

      RestClient.post("#{@url}api/profile-subscription-bulk-create-jobs/", payload.to_json, {accept: :json, revision: '2024-02-15', content_type: :json, authorization: "Klaviyo-API-Key #{@api_key}"}) do |response, request, result, &block|
        if response.code == 202
          return true
        else
          raise KlaviyoError.new(JSON.parse(response))
        end
      end
    end


    def add_to_list(email, list_id)
      payload = {
        :data => {
          :type => 'profile-subscription-bulk-create-job',
          :attributes => {
            :profiles => {
              :data => [{
                :type => 'profile',
                :attributes => {"email" => email}
              }]
            }
          },
          :relationships => {
            :list => {
              :data => {
                :type => 'list',
                "id" => list_id
              }
            }
          }
        }
      }

      RestClient.post("#{@url}api/profile-subscription-bulk-create-jobs/", payload.to_json, {accept: :json, revision: '2024-02-15', content_type: :json, authorization: "Klaviyo-API-Key #{@api_key}"}) do |response, request, result, &block|
        if response.code == 202
          return true
        else
          raise KlaviyoError.new(JSON.parse(response))
        end
      end
    end

    def get_profile(id)
      RestClient.get("#{@url}api/profiles/#{id}", {accept: :json, revision: '2024-02-15', authorization: "Klaviyo-API-Key #{@api_key}"}) do |response, request, result, &block|
        if response.code == 200
          JSON.parse(response)
        else
          raise KlaviyoError.new(response)
        end
      end
    end

    def update_profile(id, properties)
      payload = {
        :data => {
          :type => 'profile',
          :id => id,
          :attributes => properties
        } 
      }
      
      RestClient.patch("#{@url}api/profiles/#{id}", payload.to_json, {accept: :json, revision: '2024-02-15', content_type: :json, authorization: "Klaviyo-API-Key #{@api_key}"}) do |response, request, result, &block|
        if response.code == 200
          JSON.parse(response)
        else
          raise KlaviyoError.new(JSON.parse(response))
        end
      end
    end

  end
end
