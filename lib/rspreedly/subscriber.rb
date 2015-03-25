module RSpreedly

  class Subscriber < Base

    attr_accessor :active,
                  :active_until,
                  :billing_first_name,
                  :billing_last_name,
                  :card_expires_before_next_auto_renew,
                  :created_at,
                  :customer_id,
                  :eligible_for_free_trial,
                  :email,
                  :feature_level,
                  :grace_until,
                  :in_grace_period,
                  :lifetime_subscription,
                  :new_customer_id,
                  :on_trial,
                  :payment_method,
                  :payment_account_on_file,
                  :payment_account_display,
                  :ready_to_renew,
                  :ready_to_renew_since,
                  :recurring,
                  :screen_name,
                  :store_credit,
                  :store_credit_currency_code,
                  :subscription_plan_name,
                  :subscription_plan,
                  :token,
                  :updated_at,
                  :invoices

    class << self

      # Get a subscriber’s details
      # GET /api/v4/[short site name]/subscribers/[subscriber id].xml
      def find(id)
        return all if id == :all

        begin
          data = api_request(:get, "/subscribers/#{id}.xml")
          sub = Subscriber.new(data["subscriber"])
          if (data["subscriber"]["subscription_plan_version"])
            sub.subscription_plan = SubscriptionPlan.new(data["subscriber"]["subscription_plan_version"])
          end
          sub
        rescue RSpreedly::Error::NotFound
          nil
        end
      end

      # Get a list of all subscribers (more)
      # GET /api/v4/[short site name]/subscribers.xml
      def all
        response = api_request(:get, "/subscribers.xml")
        return [] unless response.has_key?("subscribers")
        response["subscribers"].collect{|data| Subscriber.new(data)}
      end

      # Find subscriber's by a given attribute and get their details
      def find_by_email(email)
        subscribers = []
        all.each do |subscriber|
          subscribers << subscriber if subscriber.email == email
        end

        subscribers.count > 1 ? subscribers : subscribers.first
      end

      # Clear all subscribers from a *test* site (more)
      # DELETE /api/v4/[short site name]/subscribers.xml
      def delete_all
        !! api_request(:delete, "/subscribers.xml")
      end

      alias_method :destroy_all, :delete_all

    end

    def invoices=(data)
      @invoices = []
      data.each do |item|
        if item.is_a? Hash
          item = RSpreedly::Invoice.new(item)
        end
        @invoices << item
      end
    end

    def new_record?
      !self.token
    end

    def save
      self.new_record? ? self.create : self.update
    end

    def save!
      self.new_record? ? self.create! : self.update!
    end

    # Create a subscriber (more)
    # POST /api/v4/[short site name]/subscribers.xml
    def create!
      xml = self.to_xml(:exclude => [:payment_account_on_file, :payment_account_display])
      result = api_request(:post, "/subscribers.xml", :body => xml)
      self.attributes = result["subscriber"]
      true
    end

    def create
      begin
        create!
      rescue RSpreedly::Error::Base
        # gulp those errors down
        # TODO - set self.errors or something?
        nil
      end
    end

    # Update a Subscriber (more)
    # PUT /api/v4/[short site name]/subscribers/[subscriber id].xml
    def update!
      !! api_request(:put, "/subscribers/#{self.customer_id}.xml", :body => self.to_xml(:exclude => [:customer_id, :payment_account_on_file, :payment_account_display]))
    end

    def update
      begin
        update!
      rescue RSpreedly::Error::Base
        # gulp those errors down
        # TODO - set self.errors or something?
        nil
      end
    end

    # Delete one subscriber from a *test* site (more)
    # DELETE /api/v4/[short site name]/subscribers/[subscriber id].xml
    def destroy
      begin
        !! api_request(:delete, "/subscribers/#{self.customer_id}.xml")
      rescue RSpreedly::Error::NotFound
        nil
      end
    end
    alias_method :delete, :destroy

    # Give a subscriber a complimentary subscription (more)
    # POST /api/v4/[short site name]/subscribers/[subscriber id]/complimentary_subscriptions.xml
    def comp_subscription(subscription)
      result = api_request(:post, "/subscribers/#{self.customer_id}/complimentary_subscriptions.xml", :body => subscription.to_xml)
      self.attributes = result["subscriber"]
      true
    end

    # Give a subscriber a complimentary time extension (more)
    # POST /api/v4/[short site name]/subscribers/[subscriber id]/complimentary_time_extension.xml
    def comp_time_extension(extension)
      result = api_request(:post, "/subscribers/#{self.customer_id}/complimentary_time_extensions.xml", :body => extension.to_xml)
      self.attributes = result["subscriber"]
      true
    end

    # Add the specified fee to the subscriber's next invoice.
    # For regular subscribers, it will be collected at their next regular payment.
    # For Metered Plans, this is the next regular payment if you've hit the minimum payment required at that time.
    #
    # POST /api/v4[short site name]/subscribers/[subscriber id]/fees.xml
    def add_fee(name, amount, description = "", group = "")
      fee = Fee.new(:name => name, :amount => amount, :description => description, :group => group)
      result = api_request(:post, "/subscribers/#{self.customer_id}/fees.xml", :body => fee.to_xml) rescue nil
      !!result
    end

    # Give a subscriber a credit (or reduce credit by supplying a negative value (more)
    # POST /api/v4[short site name]/subscribers/[subscriber id]/credits.xml
    def credit(amount)
      credit = Credit.new(:amount => amount)
      result = api_request(:post, "/subscribers/#{self.customer_id}/credits.xml", :body => credit.to_xml)
      self.store_credit = (self.store_credit || 0) + amount
      true
    end

    # Programatically Stopping Auto Renew of a Subscriber (more)
    # POST /api/v4/[short site name]/subscribers/[subscriber id]/stop_auto_renew.xml
    def stop_auto_renew
      !! api_request(:post, "/subscribers/#{self.customer_id}/stop_auto_renew.xml")
    end

    # Programatically Subscribe a Subscriber to a Free Trial Plan (more)
    # POST /api/v4/[short site name]/subscribers/[subscriber id]/subscribe_to_free_trial.xml
    def subscribe_to_free_trial(plan)
      result = api_request(:post, "/subscribers/#{self.customer_id}/subscribe_to_free_trial.xml", :body => plan.to_xml)
      self.attributes = result["subscriber"]
      true
    end

    # Programatically Allow Another Free Trial (more)
    # POST /api/v4/[short site name]/subscribers/[subscriber id]/allow_free_trial.xml
    def allow_free_trial
      result = api_request(:post, "/subscribers/#{self.customer_id}/allow_free_trial.xml")
      self.attributes = result["subscriber"]
      true
    end

    # Change the subscription plan of a subscriber
    # PUT /api/v4/[short site name]/subscribers/[subscriber id]/change_subscription_plan.xml
    def change_subscription_plan(plan_id)
      new_plan = RSpreedly::SubscriptionPlan.new(:id => plan_id)
      !! api_request(:put, "/subscribers/#{self.customer_id}/change_subscription_plan.xml", :body => new_plan.to_xml)
    end

    def grant_lifetime_subscription(feature_level)
      subscription = LifetimeComplimentarySubscription.new(:feature_level => feature_level)
      result = api_request(:post, "/subscribers/#{self.customer_id}/lifetime_complimentary_subscriptions.xml", :body => subscription.to_xml)
      self.attributes = result["subscriber"]
      true
    end

    def subscribe_link(subscription_plan_id, screen_name, return_url=nil)
      params = return_url.nil? ? "" : "?return_url=" + return_url
      "https://spreedly.com/#{RSpreedly::Config.site_name}/subscribers/#{self.customer_id}/subscribe/#{subscription_plan_id}/#{screen_name}#{params}"
    end

    def subscription_link(return_url=nil)
      params = return_url.nil? ? "" : "?return_url=" + return_url
      "https://spreedly.com/#{RSpreedly::Config.site_name}/subscriber_accounts/#{self.token}#{params}"
    end

    def to_xml(opts={})

      # the api doesn't let us send these things
      # so let's strip them out of the XML
      exclude = [
        :active,       :active_until,               :card_expires_before_next_auto_renew,
        :created_at,   :eligible_for_free_trial,    :feature_level,
        :grace_until,  :in_grace_period,            :lifetime_subscription,
        :on_trial,     :ready_to_renew,             :recurring,
        :store_credit, :store_credit_currency_code, :subscription_plan_name,
        :token,        :updated_at,                 :ready_to_renew_since,
        :invoices,     :subscription_plan
      ]

      opts[:exclude] ||= []
      opts[:exclude] |= exclude

      super(opts)
    end
  end
end
