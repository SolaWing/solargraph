# frozen_string_literal: true

require 'set'

module Solargraph
  class ApiMap
    class Store
      # @return [Enumerable<Solargraph::Pin::Base>]
      attr_reader :pins

      # @param pins [Enumerable<Solargraph::Pin::Base>]
      # @param base [Store, nil] previous new store, use to calculate increment diff and boost performance. base is readonly
      def initialize pins = [], base = nil
        if base && (pins.length - base.pins.length).abs * 10 < pins.length # use only when diff is small
          # must exist attribute, see #index usage
          @pins = base.instance_variable_get('@pins') # will replace by value, will not modify directly, so don't need dup
          # @extend_references     = base.instance_variable_get('@extend_references').transform_values(&:dup)
          # @include_references    = base.instance_variable_get('@include_references').transform_values(&:dup)
          # @prepend_references    = base.instance_variable_get('@prepend_references').transform_values(&:dup)
          # @superclass_references = base.instance_variable_get('@superclass_references').transform_values(&:dup)
          # @pin_select_cache      = base.instance_variable_get('@pin_select_cache').transform_values(&:dup)
          @namespace_map         = base.instance_variable_get('@namespace_map').transform_values(&:dup)
          @path_pin_hash         = base.instance_variable_get('@path_pin_hash').transform_values(&:dup)
          @pin_class_hash        = base.instance_variable_get('@pin_class_hash').transform_values(&:dup)
          @namespaces            = base.instance_variable_get('@namespaces').dup
          # has default setter, dup will affect original. lazy calculate instead
          # @fqns_pins_map = base.instance_variable_get('@fqns_pins_map')
          # @named_macros = base.instance_variable_get('@named_macros')
        else
          @pins = ::Set.new
          # @extend_references     = {}
          # @include_references    = {}
          # @prepend_references    = {}
          # @superclass_references = {}
          # @pin_select_cache      = {}
          @namespace_map         = {}
          @path_pin_hash         = {}
          @pin_class_hash        = {}
          @namespaces            = ::Set.new
        end

        index pins
      end

      # @param fqns [String]
      # @param visibility [Array<Symbol>]
      # @return [Enumerable<Solargraph::Pin::Base>]
      def get_constants fqns, visibility = [:public]
        namespace_children(fqns).select { |pin|
          !pin.name.empty? && (pin.is_a?(Pin::Namespace) || pin.is_a?(Pin::Constant)) && visibility.include?(pin.visibility)
        }
      end

      # @param fqns [String]
      # @param scope [Symbol]
      # @param visibility [Array<Symbol>]
      # @return [Enumerable<Solargraph::Pin::Base>]
      def get_methods fqns, scope: :instance, visibility: [:public]
        namespace_children(fqns).select do |pin|
          pin.is_a?(Pin::Method) && pin.scope == scope && visibility.include?(pin.visibility)
        end
      end

      # @param fqns [String]
      # @return [String, nil]
      def get_superclass fqns
        return superclass_references[fqns].first if superclass_references.key?(fqns)
        return 'Object' if fqns != 'BasicObject' && namespace_exists?(fqns)
        return 'Object' if fqns == 'Boolean'
        nil
      end

      # @param fqns [String]
      # @return [Array<String>]
      def get_includes fqns
        include_references[fqns] || []
      end

      # @param fqns [String]
      # @return [Array<String>]
      def get_prepends fqns
        prepend_references[fqns] || []
      end

      # @param fqns [String]
      # @return [Array<String>]
      def get_extends fqns
        extend_references[fqns] || []
      end

      # @param path [String]
      # @return [Enumerable<Solargraph::Pin::Base>]
      def get_path_pins path
        path_pin_hash[path] || []
      end

      # @param fqns [String]
      # @param scope [Symbol] :class or :instance
      # @return [Enumerable<Solargraph::Pin::Base>]
      def get_instance_variables(fqns, scope = :instance)
        all_instance_variables.select { |pin|
          pin.binder.namespace == fqns && pin.binder.scope == scope
        }
      end

      # @param fqns [String]
      # @return [Enumerable<Solargraph::Pin::Base>]
      def get_class_variables(fqns)
        namespace_children(fqns).select{|pin| pin.is_a?(Pin::ClassVariable)}
      end

      # @return [Enumerable<Solargraph::Pin::Base>]
      def get_symbols
        symbols.uniq(&:name)
      end

      # @param fqns [String]
      # @return [Boolean]
      def namespace_exists?(fqns)
        fqns_pins(fqns).any?
      end

      # @return [Set<String>]
      def namespaces
        @namespaces ||= ::Set.new
      end

      # @return [Enumerable<Solargraph::Pin::Base>]
      def namespace_pins
        pins_by_class(Solargraph::Pin::Namespace)
      end

      # @return [Enumerable<Solargraph::Pin::Method>]
      def method_pins
        pins_by_class(Solargraph::Pin::Method)
      end

      # @param fqns [String]
      # @return [Array<String>]
      def domains(fqns)
        result = []
        fqns_pins(fqns).each do |nspin|
          result.concat nspin.domains
        end
        result
      end

      # @return [Hash]
      def named_macros
        @named_macros ||= begin
          result = {}
          pins.each do |pin|
            pin.macros.select{|m| m.tag.tag_name == 'macro' && !m.tag.text.empty? }.each do |macro|
              next if macro.tag.name.nil? || macro.tag.name.empty?
              result[macro.tag.name] = macro
            end
          end
          result
        end
      end

      # @return [Enumerable<Pin::Block>]
      def block_pins
        pins_by_class(Pin::Block)
      end

      def inspect
        # Avoid insane dumps in specs
        to_s
      end

      # @param klass [Class]
      # @return [Enumerable<Solargraph::Pin::Base>]
      def pins_by_class klass
        @pin_select_cache[klass] ||= @pin_class_hash.each_with_object(::Set.new) { |(key, o), n| n.merge(o) if key <= klass }
      end

      private

      # @param fqns [String]
      # @return [Array<Solargraph::Pin::Namespace>]
      def fqns_pins fqns
        return [] if fqns.nil?
        if fqns.include?('::')
          parts = fqns.split('::')
          name = parts.pop
          base = parts.join('::')
        else
          base = ''
          name = fqns
        end
        fqns_pins_map[[base, name]]
      end

      def fqns_pins_map
        @fqns_pins_map ||= Hash.new do |h, (base, name)|
          value = namespace_children(base).select { |pin| pin.name == name && pin.is_a?(Pin::Namespace) }
          h[[base, name]] = value
        end
      end

      # @return [Enumerable<Solargraph::Pin::Symbol>]
      def symbols
        pins_by_class(Pin::Symbol)
      end

      def superclass_references
        @superclass_references ||= {}
      end

      def include_references
        @include_references ||= {}
      end

      def prepend_references
        @prepend_references ||= {}
      end

      def extend_references
        @extend_references ||= {}
      end

      # @param name [String]
      # @return [Enumerable<Solargraph::Pin::Base>]
      def namespace_children name
        namespace_map[name] || []
      end

      # @return [Hash]
      def namespace_map
        @namespace_map ||= {}
      end

      def all_instance_variables
        pins_by_class(Pin::InstanceVariable)
      end

      def path_pin_hash
        @path_pin_hash ||= {}
      end

      # replace current state with pins.
      #
      # @return [void]
      def index pins
        pins = pins.to_set
        if @pins.empty? # first not need diff
          added_pins = pins
          @pin_class_hash = added_pins.classify(&:class)
          @namespace_map = added_pins.classify(&:namespace)
          @path_pin_hash = added_pins.classify(&:path)
          @namespaces = path_pin_hash.keys.compact.to_set
        else
          changed = pins ^ @pins
          changed = changed.classify {|v| pins.include? v}
          added_pins = changed[true]
          remove_pins = changed[false]

          clean_in_valueset = proc do |store, patch|
            patch.map do |k, v|
              # delete values, if empty, delete key
              set = store[k] and set.subtract(v).empty? and store.delete(k) and k
            end
          end
          if remove_pins
            clean_in_valueset[@pin_class_hash, remove_pins.classify(&:class)]
            clean_in_valueset[@namespace_map, remove_pins.classify(&:namespace)]
            removed_path = clean_in_valueset[@path_pin_hash, remove_pins.classify(&:path)]
            @namespaces.subtract removed_path
          end
          if added_pins
            added_pins.classify(&:class).each {|k, v| (@pin_class_hash[k] ||= ::Set.new).merge v }
            added_pins.classify(&:namespace).each {|k, v| (@namespace_map[k] ||= ::Set.new).merge v }
            path_pin_hash = added_pins.classify(&:path)
            path_pin_hash.each {|k, v| (@path_pin_hash[k] ||= ::Set.new).merge v }
            @namespaces.merge path_pin_hash.keys.compact
          end
        end
        @pins = pins

        @pin_select_cache = {}
        pins_by_class(Pin::Reference::Include).each do |pin|
          include_references[pin.namespace] ||= []
          include_references[pin.namespace].push pin.name
        end
        pins_by_class(Pin::Reference::Prepend).each do |pin|
          prepend_references[pin.namespace] ||= []
          prepend_references[pin.namespace].push pin.name
        end
        pins_by_class(Pin::Reference::Extend).each do |pin|
          extend_references[pin.namespace] ||= []
          extend_references[pin.namespace].push pin.name
        end
        pins_by_class(Pin::Reference::Superclass).each do |pin|
          superclass_references[pin.namespace] ||= []
          superclass_references[pin.namespace].push pin.name
        end
        pins_by_class(Pin::Reference::Override).each do |ovr|
          pin = get_path_pins(ovr.name).first
          next if pin.nil?
          new_pin = if pin.path.end_with?('#initialize')
            get_path_pins(pin.path.sub(/#initialize/, '.new')).first
          end
          (ovr.tags.map(&:tag_name) + ovr.delete).uniq.each do |tag|
            pin.docstring.delete_tags tag.to_sym
            new_pin.docstring.delete_tags tag.to_sym if new_pin
          end
          ovr.tags.each do |tag|
            pin.docstring.add_tag(tag)
            new_pin.docstring.add_tag(tag) if new_pin
          end
        end
      end
    end
  end
end
