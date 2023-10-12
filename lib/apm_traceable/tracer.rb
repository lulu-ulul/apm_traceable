# frozen_string_literal: true

require 'datadog/tracing'
require 'active_support/inflector'

module ApmTraceable
  # トレース対象クラスにincludeして利用するTracerクラス
  # トレースに利用する以下2メソッドが利用可能になる
  #   - trace_span: 指定したブロックをトレースする
  #   - trace_methods: 指定したメソッドの呼び出し全体をトレースする
  module Tracer
    def self.included(klass)
      klass.extend(ClassMethods)
    end

    # include先クラスで利用可能にするクラスメソッド群のモジュール
    module ClassMethods
      # 指定したメソッド群をトレース対象にする.
      # 引数を複数指定すると、すべてのメソッドがそれぞれトレース対象になる.
      #
      # fg.
      # class Test
      #   include DatadogTraceable
      #   trace_methods :method_a, :method_b
      # end
      def trace_methods(*method_names)
        # 計測対象をラップする必要があるため、計測対象メソッドと同名で計測用メソッドを定義したモジュールを生成する
        wrapper = Module.new do
          method_names.each do |method_name|
            define_method method_name do |*args, **options|
              trace_span(method_name.to_s) { super(*args, **options) }
            end
          end
        end

        # 計測対象メソッドより先に計測用メソッドが呼び出されないといけないため、
        # prependして継承チェインの先頭側に追加する
        prepend(wrapper)
      end
    end

    # 指定したブロックをトレース対象にする. Datadog::Tracing#trace のラッパーメソッド.
    # リソース名指定のみ必須で、それ以外に指定したオプションは Datadog::Tracing#trace にそのまま渡される.
    #
    # fg.
    # class Test
    #   include DatadogTraceable
    #
    #   def test_method
    #     trace_span('mySpan') { some_heavy_process }
    #   end
    # end
    def trace_span(resource_name, **options, &block)
      Datadog::Tracing.trace(trace_name, **options.merge(service: service_name, resource: resource_name), &block)
    end

    private

    def trace_name
      # include 先のクラス名を利用して `product.search_controller` のような文字列を作る
      # template から呼び出された場合、 self が ActionView::Base のオブジェクトとなるため controller から生成する
      (self.class.name || controller.class.name).underscore&.tr('/', '.')
    end

    def service_name
      ApmTraceable.configuration.service_name
    end
  end
end
