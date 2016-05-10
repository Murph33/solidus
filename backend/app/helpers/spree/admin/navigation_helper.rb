module Spree
  module Admin
    module NavigationHelper
      # Add items to current page breadcrumb heirarchy
      def add_breadcrumb(*ancestors, &block)
        breadcrumbs.concat(ancestors) if ancestors.present?
        breadcrumbs.push(capture(&block)) if block_given?
      end

      def add_page_title_to_breadcrumbs
        ActiveSupport::Deprecation.warn('content_for(:page_title) is deprecated, use add_breadcrumb')
        add_breadcrumb(content_for(:page_title))
      end

      # Render Bootstrap style breadcrumbs
      def render_breadcrumbs
        add_page_title_to_breadcrumbs if content_for?(:page_title)
        content_tag :ol, class: 'breadcrumb' do
          safe_join breadcrumbs.collect { |level|
            content_tag(:li, level, class: "separator #{level == breadcrumbs.last ? 'active' : ''}")
          }
        end
      end

      def page_title
        if content_for?(:title)
          content_for(:title)
        elsif content_for?(:page_title)
          content_for(:page_title)
        elsif breadcrumbs.any?
          strip_tags(breadcrumbs.last)
        else
          Spree.t(controller.controller_name, default: controller.controller_name.titleize)
        end
      end

      # Make an admin tab that coveres one or more resources supplied by symbols
      # Option hash may follow. Valid options are
      #   * :label to override link text, otherwise based on the first resource name (translated)
      #   * :route to override automatically determining the default route
      #   * :match_path as an alternative way to control when the tab is active, /products would match /admin/products, /admin/products/5/variants etc.
      def tab(*args, &_block)
        options = { label: args.first.to_s }

        if args.last.is_a?(Hash)
          options = options.merge(args.pop)
        end
        options[:route] ||= "admin_#{args.first}"

        destination_url = options[:url] || spree.send("#{options[:route]}_path")
        label = Spree.t(options[:label], scope: [:admin, :tab])

        css_classes = []

        if options[:icon]
          link = link_to_with_icon(options[:icon], label, destination_url)
          css_classes << 'tab-with-icon'
        else
          link = link_to(label, destination_url)
        end

        selected = if options[:match_path].is_a? Regexp
          request.fullpath =~ options[:match_path]
        elsif options[:match_path]
          request.fullpath.starts_with?("#{admin_path}#{options[:match_path]}")
        else
          request.fullpath.starts_with?(destination_url) ||
            args.include?(controller.controller_name.to_sym)
        end
        css_classes << 'selected' if selected

        if options[:css_class]
          css_classes << options[:css_class]
        end
        content_tag('li', link + (yield if block_given?), class: css_classes.join(' ') )
      end

      def link_to_clone(resource, options = {})
        options[:data] = { action: 'clone' }
        link_to_with_icon('copy', Spree.t(:clone), clone_object_url(resource), options)
      end

      def link_to_new(resource)
        options[:data] = { action: 'new' }
        link_to_with_icon('plus', Spree.t(:new), edit_object_url(resource))
      end

      def link_to_edit(resource, options = {})
        url = options[:url] || edit_object_url(resource)
        options[:data] = { action: 'edit' }
        link_to_with_icon('edit', Spree.t('actions.edit'), url, options)
      end

      def link_to_edit_url(url, options = {})
        options[:data] = { action: 'edit' }
        link_to_with_icon('edit', Spree.t('actions.edit'), url, options)
      end

      def link_to_delete(resource, options = {})
        url = options[:url] || object_url(resource)
        name = options[:name] || Spree.t('actions.delete')
        options[:class] = "delete-resource"
        options[:data] = { confirm: Spree.t(:are_you_sure), action: 'remove' }
        link_to_with_icon 'trash', name, url, options
      end

      def link_to_with_icon(icon_name, text, url, options = {})
        options[:class] = (options[:class].to_s + " fa fa-#{icon_name} icon_link with-tip").strip
        options[:class] += ' no-text' if options[:no_text]
        options[:title] = text if options[:no_text]
        text = options[:no_text] ? '' : content_tag(:span, text, class: 'text')
        options.delete(:no_text)
        link_to(text, url, options)
      end

      def icon(icon_name)
        icon_name ? content_tag(:i, '', class: icon_name) : ''
      end

      def button(text, icon_name = nil, button_type = 'submit', options = {})
        button_tag(text, options.merge(type: button_type, class: "fa fa-#{icon_name} button"))
      end

      def button_link_to(text, url, html_options = {})
        html_options = { class: '' }.merge(html_options)
        if html_options[:method] &&
           html_options[:method].to_s.downcase != 'get' &&
           !html_options[:remote]
          form_tag(url, method: html_options.delete(:method)) do
            button(text, html_options.delete(:icon), nil, html_options)
          end
        else
          html_options[:class] += ' button'

          if html_options[:icon]
            html_options[:class] += " fa fa-#{html_options[:icon]}"
          end
          link_to(text, url, html_options)
        end
      end

      def configurations_menu_item(link_text, url, description = '')
        %(<tr>
          <td>#{link_to(link_text, url)}</td>
          <td>#{description}</td>
        </tr>
        ).html_safe
      end

      def configurations_sidebar_menu_item(link_text, url, options = {})
        is_active = url.ends_with?(controller.controller_name) ||
                    url.ends_with?("#{controller.controller_name}/edit") ||
                    url.ends_with?("#{controller.controller_name.singularize}/edit")
        options[:class] = is_active ? 'active' : nil
        content_tag(:li, options) do
          link_to(link_text, url)
        end
      end

      def settings_tab_item(link_text, url, options = {})
        is_active = url.ends_with?(controller.controller_name) ||
                    url.ends_with?("#{controller.controller_name}/edit") ||
                    url.ends_with?("#{controller.controller_name.singularize}/edit")
        options[:class] = 'fa'
        options[:class] += ' active' if is_active
        options[:datahook] = "admin_settings_#{link_text.downcase.tr(' ', '_')}"
        content_tag(:li, options) do
          link_to(link_text, url)
        end
      end

      private

      def breadcrumbs
        @breadcrumbs ||= []
      end
    end
  end
end
