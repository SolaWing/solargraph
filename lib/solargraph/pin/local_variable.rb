module Solargraph
  module Pin
    class LocalVariable < BaseVariable
      def initialize source, node, namespace, ancestors
        super(source, node, namespace)
        @tree = []
        ancestors.each do |parent|
          if [:block, :def, :defs, :class, :module, :source].include? parent.type
            @tree.push parent
            break unless parent.type == :block
          end
        end
      end

      def visible_from? node
        return true if @tree[0] == node
        parents = source.tree_for(node)
        return false if parents.nil?
        parents.each do |p|
          return true if @tree[0] == p
          return false if p.type == :block
          return false if [:def, :defs, :class, :module].include?(p.type)
        end
        false
      end
    end
  end
end
