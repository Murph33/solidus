module Spree
  module Stock
    class Estimator
      class ShipmentRequired < StandardError; end
      class OrderRequired < StandardError; end

      # Estimate the shipping rates for a package.
      #
      # @param package [Spree::Stock::Package] the package to be shipped
      # @param frontend_only [Boolean] restricts the shipping methods to only
      #   those marked frontend if truthy
      # @return [Array<Spree::ShippingRate>] the shipping rates sorted by
      #   descending cost, with the least costly marked "selected"
      def shipping_rates(package, frontend_only = true)
        raise ShipmentRequired if package.shipment.nil?
        raise OrderRequired if package.shipment.order.nil?

        rates = calculate_shipping_rates(package)
        rates.select! { |rate| rate.shipping_method.frontend? } if frontend_only
        choose_default_shipping_rate(rates)
        Spree::Config.shipping_rate_sorter_class.new(rates).sort
      end

      private

      def choose_default_shipping_rate(shipping_rates)
        unless shipping_rates.empty?
          default_shipping_rate = Spree::Config.shipping_rate_selector_class.new(shipping_rates).find_default
          default_shipping_rate.selected = true
        end
      end

      def calculate_shipping_rates(package)
        shipping_methods(package).map do |shipping_method|
          cost = shipping_method.calculator.compute(package)
          tax_category = shipping_method.tax_category
          if tax_category
            tax_rate = tax_category.tax_rates.detect do |rate|
              # If the rate's zone matches the order's zone, a positive adjustment will be applied.
              # If the rate is from the default tax zone, then a negative adjustment will be applied.
              # See the tests in shipping_rate_spec.rb for an example of this.d
              rate.zone == package.shipment.order.tax_zone || rate.zone.default_tax?
            end
          end

          if cost
            rate = shipping_method.shipping_rates.new(
              cost: cost,
              shipment: package.shipment
            )
            rate.tax_rate = tax_rate if tax_rate
          end

          rate
        end.compact
      end

      def shipping_methods(package)
        package.shipping_methods
          .available_for_address(package.shipment.address)
          .includes(:calculator, tax_category: :tax_rates)
          .to_a
          .select do |ship_method|
          calculator = ship_method.calculator
          calculator.available?(package) &&
            (calculator.preferences[:currency].blank? ||
             calculator.preferences[:currency] == package.shipment.order.currency)
        end
      end
    end
  end
end
