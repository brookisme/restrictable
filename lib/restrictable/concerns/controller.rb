module Restrictable
  module Controller
  extend ActiveSupport::Concern

    included do

      def self.check_restrictable!
        if !@actions_set
          before_action :check_permissions!
          before_action :check_access!
          @actions_set = true
        end
      end

      def self.allow_client hash_or_sym=nil
        set_permissions_hash("client", hash_or_sym)
      end 

      def self.allow_translator hash_or_sym=nil
        set_permissions_hash("translator", hash_or_sym)
      end 

      def self.allow_admin hash_or_sym=nil
        set_permissions_hash("admin", hash_or_sym)
      end 
      
      def self.validate_access hash_or_sym
        set_access_hash(hash_or_sym)
      end

      def self.restrict_object object
        @restricted_object = object
      end

      def self.set_permissions_hash role, hash_or_sym
        if hash_or_sym.blank? || hash_or_sym == :all
          permissions_hash[role] = :all
        elsif hash_or_sym == :none
          permissions_hash[role] = :none
        else
          permissions_hash[role] = hash_or_sym
        end
      end
      
      def self.set_access_hash hash_or_sym
        @access_hash = {}
        unless hash_or_sym.blank?
          if hash_or_sym == :all
            @access_hash[:all] = true
          elsif hash_or_sym == :none
            @access_hash[:none] = true
          else
            @access_hash = hash_or_sym
          end          
        end
      end

      def self.permissions_hash
        @permissions_hash ||= { "admin" => :all }
      end

      def self.access_hash
        @access_hash ||= { only: [:show, :edit, :update, :destroy] }
      end

      def self.restricted_object
        @restricted_object
      end

      def validate_object object        
        set_subject(object)
      end
    end




  private

    def check_permissions!
      if !defined?(current_admin)
        redirect_to :root, notice: admin_does_not_exist_warning
      else
        unless current_admin.is_super? || is_allowed?
          redirect_to :root, notice: does_not_have_permission_warning
        end
      end
    end

    def check_access!
      if should_validate_access?
        if !defined?(current_admin)
          redirect_to :root, notice: admin_does_not_exist_warning
        else
          unless is_valid_admin?
            redirect_to :root, notice: does_not_have_access_warning
          end
        end
      end
    end

    def is_allowed?
      unless current_admin.blank?
        permissions_hash = self.class.permissions_hash
        role = current_admin.role
        unless permissions_hash[role].blank?
          if permissions_hash[role] == :all
            has_permission = true
          elsif permissions_hash[role] == :none
            has_permission = false
          elsif !permissions_hash[role][:only].blank?
            has_permission = permissions_hash[role][:only].include?(action_name.to_sym)
          elsif !permissions_hash[role][:except].blank?
            has_permission = !permissions_hash[role][:except].include?(action_name.to_sym)
          end
        end
      end
      has_permission 
    end

    def should_validate_access?
      access_hash = self.class.access_hash
      if access_hash[:none] === true
        should_validate = false
      elsif access_hash[:all] === true
        should_validate = true
      elsif !access_hash[:only].blank?
        should_validate = access_hash[:only].include?(action_name.to_sym)
      elsif !access_hash[:except].blank?
        should_validate = !access_hash[:except].include?(action_name.to_sym)
      end
      should_validate
    end

    def is_valid_admin?
      object = self.class.restricted_object
      object = instance_variable_get("@#{controller_name.singularize}") if object.nil?
      unless object.blank?
        object.class.for_admin(current_admin).include?(object)
      end
    end


    #
    # Notice/Exception Messages
    #

    def does_not_have_permission_warning
      "You don't have permission to see that!"    
    end
    
    def does_not_have_access_warning
      "You don't have access to see that!"
    end
    
    def admin_does_not_exist_warning
      "Admin does not exist!"
    end

  end
end
