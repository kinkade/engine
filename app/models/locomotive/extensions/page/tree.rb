module Locomotive
  module Extensions
    module Page
      module Tree

        extend ActiveSupport::Concern

        included do
          include ::Mongoid::Tree
          include ::Mongoid::Tree::Ordering

          ## fields ##
          field :depth, :type => Integer, :default => 0

          ## callbacks ##
          before_save     :persist_depth
          before_destroy  :delete_descendants

          ## indexes ##
          index :position
          index [:depth.asc, :position.asc]

          ## scopes ##
          default_scope :where => {} # disable the default_scope from the Mongoid::Tree gem
        end

        module ClassMethods

          # Returns the pages tree from the site with the most minimal amount of queries.
          # This method should only be used for read-only purpose since
          # the mongodb returns the minimal set of required attributes to build
          # the tree.
          #
          # @param [ Locomotive::Site ] site The site owning the pages
          #
          # @return [ Array ] The first array of pages (depth = 0)
          #
          def quick_tree(site, minimal_attributes = true)
            pages = (minimal_attributes ? site.pages.minimal_attributes : site.pages).order_by([:depth.asc, :position.asc]).to_a

            tmp = []

            while !pages.empty?
              tmp << _quick_tree(pages.delete_at(0), pages)
            end

            tmp
          end

          #:nodoc:
          def _quick_tree(current_page, pages)
            i, children = 0, []

            while !pages.empty?
              page = pages[i]

              break if page.nil?

              if page.parent_id == current_page.id
                page = pages.delete_at(i)

                children << _quick_tree(page, pages)
              else
                i += 1
              end
            end

            current_page.instance_eval do
              def children=(list); @children = list; end
              def children; @children || []; end
            end

            current_page.children = children

            current_page
          end

        end

        # Returns the children of this node but with the minimal set of required attributes
        #
        # @return [ Array ] The children pages ordered by their position
        #
        def children_with_minimal_attributes
          self.children.minimal_attributes
        end

        # Assigns the new position of each child of this node.
        #
        # @param [ Array ] ids The ordered list of page ids (string)
        #
        def sort_children!(ids)
          cached_children = self.children.to_a
          ids.each_with_index do |id, position|
            child = cached_children.detect { |p| p._id == BSON::ObjectId(id) }
            child.position = position
            child.save
          end
        end

        def depth
          self.parent_ids.count
        end

        protected

        def persist_depth
          self.attributes['depth'] = self.depth
          self.depth_will_change!
        end

      end
    end
  end
end