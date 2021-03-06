module Bindgen
  module CallBuilder
    # Builder for calls made from C++ to a Crystal `CrystalProc`.
    class CrystalFromCpp
      def initialize(@db : TypeDatabase)
      end

      # Calls the *method*, using the *proc_name* to call-through to Crystal.
      def build(method : Parser::Method, receiver = "self") : Call
        pass = Crystal::Pass.new(@db)
        argument = Crystal::Argument.new(@db)

        arguments = method.arguments.map_with_index do |arg, idx|
          caller = pass.from_binding(arg, qualified: true)
          callee = pass.from_wrapper(arg)
          result = combine_result(caller, callee)
          result.to_argument(argument.name(arg, idx))
        end

        callee = pass.to_wrapper(method.return_type)
        caller = pass.to_binding(method.return_type, to_unsafe: true, qualified: true)
        result = combine_result(caller, callee)

        Call.new(
          origin: method,
          name: method.crystal_name,
          result: result,
          arguments: arguments,
          body: Body.new(@db, receiver),
        )
      end

      # Combines the results *outer* to *inner*.
      private def combine_result(outer, inner)
        conv_out = outer.conversion
        conv_in = inner.conversion

        if conv_out && conv_in
          conversion = Util.template(conv_out, conv_in)
        else
          conversion = conv_out || conv_in
        end

        Call::Result.new(
          type: outer.type,
          type_name: outer.type_name,
          pointer: outer.pointer,
          reference: outer.reference,
          conversion: conversion,
        )
      end

      class Body < Call::Body
        def initialize(@db : TypeDatabase, @receiver : String)
        end

        def to_code(call : Call, platform : Graph::Platform) : String
          formatter = Crystal::Format.new(@db)
          typer = Crystal::Typename.new(@db)
          func_result = typer.full(call.result)

          func_args = call.arguments.map { |arg| typer.full(arg) }
          func_args << func_result # Add return type

          pass_args = call.arguments.map(&.call).join(", ")
          proc_args = func_args.join(", ")
          block_arg_names = call.arguments.map(&.name).join(", ")
          block_args = "|#{block_arg_names}|" unless pass_args.empty?

          body = "#{@receiver}.#{call.name}(#{pass_args})"
          if templ = call.result.conversion
            body = Util.template(templ, body)
          end

          %[Proc(#{proc_args}).new{#{block_args} #{body} }]
        end
      end
    end
  end
end
