module ActiveRecord::Validations

  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods

    # The validates_existence_of validator checks that a foreign key in a belongs_to
    # association points to an exisiting record. If :allow_nil => true, then the key
    # itself may be blank/nil. A non-blank key requires that the foreign object must exist.
    # Works with polymorphic belongs_to.
    def validates_existence_of(*attr_names)
      configuration = { :message => "does not exist", :on => :save }
      configuration.update(attr_names.pop) if attr_names.last.is_a?(Hash)

      attr_names.each do |attr_name|
        unless (assoc = reflect_on_association(attr_name)) && assoc.macro == :belongs_to
          raise ArgumentError, "Cannot validate existence of :#{attr_name} because it is not a belongs_to association."
        end
        send(validation_method(configuration[:on])) do |record|
          unless configuration[:if] && !evaluate_condition(configuration[:if], record)
            
            # Allow using associations that don't use ID as a foreign key
            assoc_key = (assoc.options[:primary_key] || :id)

            fk_value = record[assoc.primary_key_name]
            next if fk_value.blank? && configuration[:allow_nil]
              
            if (foreign_type = assoc.options[:foreign_type]) # polymorphic
              foreign_type_value = record[assoc.options[:foreign_type]]
              
              assoc_class = nil
              
              if !foreign_type_value.blank?
                begin
                  assoc_class = foreign_type_value.constantize
                rescue
                end
              else
                record.errors.add(attr_name, configuration[:message])
                next
              end
            else # not polymorphic
              assoc_class = assoc.klass
            end
            
            # Allow checking to see if associated item has same field value
            if scope = configuration[:scope]
              Array(scope).map do |scope_item|
                scope_value = record.send(scope_item)
                unless assoc_class && assoc_class.find(:first, :conditions => [
                  "#{assoc_key} = ? AND #{scope_item} = ?", fk_value, scope_value
                ])
                  record.errors.add(attr_name, configuration[:message]) 
                end
              end
            else
              unless assoc_class && assoc_class.exists?(
                ["#{assoc_key} = ?", fk_value]
              )
                record.errors.add(attr_name, configuration[:message]) 
              end
            end
              
          end
        end
      end # end attr_names
    end

  end # ClassMethods

end
