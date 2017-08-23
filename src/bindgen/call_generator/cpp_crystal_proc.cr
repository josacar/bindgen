module Bindgen
  module CallGenerator
    # A generator for C++ `CrystalProc<T, Args...>` template variables.
    class CppCrystalProc
      include CppMethods

      def initialize(@type_only = false)
      end

      # *call* should be generated by `CallAnalyzer::CppToCrystalProc`
      def generate(call : Call) : String
        if @type_only
          cpp_crystal_proc call
        else
          "#{cpp_crystal_proc call} #{call.name};"
        end
      end

      def as_result(call : Call) : Call::Result
        Call::Result.new(
          type: call.result.type,
          type_name: cpp_crystal_proc(call),
          reference: false,
          pointer: 0,
          conversion: nil,
        )
      end
    end
  end
end