# Patched to the ApplicationController
module RedmineClf2
  module Patches
    module ApplicationControllerPatch
      def self.included(base)
        base.extend ClassMethods
        base.send(:include, InstanceMethods)

        base.class_eval do
          cattr_accessor :subdomain_languages

          # Skip Redmine's default :set_localization
          skip_before_filter :set_localization
          # Add our :set_localization method to the start of the chain
          prepend_before_filter_if_not_already_added :set_localization
          # Add set_localization_from_domain to the very beginning
          prepend_before_filter_if_not_already_added :switch_language_from_domain

          alias_method_chain :set_localization, :clf_mods
          alias_method_chain :url_for, :language_in_url

          base.load_subdomains_file

          helper :clf2
        end
      end
    end

    module ClassMethods
      # Wraps +prepend_before_filter+ in a test to make sure a filter
      # isn't being added multiple times, which can happen with class
      # reloading in development mode
      def prepend_before_filter_if_not_already_added(method)
        unless filter_already_added? method
          prepend_before_filter method
        end
      end

      # Wraps +before_filter+ in a test to make sure a filter
      # isn't being added multiple times, which can happen with class
      # reloading in development mode
      def before_filter_if_not_already_added(method)
        unless filter_already_added? method
          before_filter method
        end
      end

      # Checks if a filter has already been added to the filter_chain
      def filter_already_added?(filter)
        return self.filter_chain.collect(&:method).include?(filter)
      end

      # Load the subdomains.yml file to configure the subdomain
      # to language mapping.  In development mode this will be
      # reloaded with each request but in production, it will be cached.
      def load_subdomains_file
        subdomains_file = File.join(Rails.plugins['redmine_clf2'].directory,'config','subdomains.yml')
        if File.exists?(subdomains_file)
          self.subdomain_languages = YAML::load(File.read(subdomains_file))
          logger.debug "Loaded subdomains file"
        else
          logger.error "Subdomains file not found at #{domain_file}. Subdomain specific languages will not be used."
        end
      end
    end

    # Additional InstanceMethods
    module InstanceMethods
      def switch_language_to(language)
        # Guard against a loop since this runs for the
        # LanguageSwitcherController also
        unless params[:controller] == 'language_switcher'
          redirect_to :controller => 'language_switcher', :action => language
        end
      end

      def switch_language_from_domain
        # Skip if language is already set
        return true if session[:language]
      end

      def set_current_language_from_session
        if session[:language]
          User.current.language = session[:language]
          current_language = session[:language]
        else
          User.current.language = nil unless User.current.logged?
        end
      end

      def set_localization_with_clf_mods
        logger.debug "In set_localization_with_clf_mods"
        switch_language_to(:french) if request.request_uri =~ /\/french$/
        switch_language_to(:english) if request.request_uri =~ /\/english$/
        set_current_language_from_session

        # Most of this is copied from the core, except as noted.
        lang = nil
        if User.current.language.present? # Modified from core
          lang = find_language(User.current.language)
        end
        if lang.nil? && request.env['HTTP_ACCEPT_LANGUAGE']
          accept_lang = parse_qvalues(request.env['HTTP_ACCEPT_LANGUAGE']).first.downcase
          if !accept_lang.blank?
            lang = find_language(accept_lang) || find_language(accept_lang.split('-').first)
          end
        end
        lang ||= Setting.default_language
        set_language_if_valid(lang)

      end

      def url_for_with_language_in_url(options)
        # Pass without language if options isn't a hash (e.g. url string)
        unless options.respond_to?(:merge)
          return url_for_without_language_in_url(options)
        end

        case current_language
        when :en
          url_for_without_language_in_url(options.merge(:lang => 'eng'))
        when :fr
          url_for_without_language_in_url(options.merge(:lang => 'fra'))
        else
          url_for_without_language_in_url(options)
        end
      end
    end # InstanceMethods
  end
end
