require 'pry'
require 'drb/drb'
require 'drb/ssl'
require "readline"
require 'ripper'

module SmartNotebook

  class RemoteWorker
    attr_accessor :worker, :uri, :drb_obj

    def initialize(uri)
      connect(uri)
    end

    def connect(obj)
      uri = obj.class == String ? obj : obj.uri
      drb_obj = DRbObject.new_with_uri(uri)
      worker = drb_obj[:worker]

      begin
        worker.status

        @worker = worker
        @uri = uri
        @drb_obj = drb_obj
      rescue DRb::DRbConnError
        puts "connect to server #{uri} failed"
      end

      return @uri
    end

    def check_connect()
      AutoRetry.new.catch(->() {@worker = @drb_obj[:worker]}) do
        @worker.status
      end
    end

    def restart()
      check_connect()
      @worker.restart()
    end

    def stdout()
      check_connect()
      @worker.stdout
    end

    def stderr()
      check_connect()
      @worker.stderr
    end

    def prompt(type)
      check_connect()
      @worker.prompt(type)
    end

    def find_command(cmd)
      check_connect()
      @worker.find_command(cmd)
    end

    def run_command(cmd, editor_proc=nil, output_proc=nil, system_proc = nil)
      check_connect()
      @worker.editor_proc = editor_proc
      @worker.run_command(cmd, output_proc, system_proc)
      @worker.editor_proc = nil
    end

    def eval(code)
      check_connect()
      @worker.eval(code)
    end

    def eval_await(code,output_proc,result_proc)
      check_connect()
      @worker.eval_await(code,output_proc,result_proc)
    end

    def eval_async(code,output_proc,result_proc)
      check_connect()
      @worker.eval_async(code,output_proc,result_proc)
    end

    def method_missing(m, *args, &block)
      return if m==:to_ary

      code = "#{m}"

      code_args = []

      if args!=[] then
        # obj_str = Marshal.dump(args)
        # code_args << "*Marshal.load('#{obj_str}')"

        @worker.storage_set(:eval_args,args)
        code_args << " *SmartNotebook::WorkerServer.storage_args(:eval_args) "

      end

      if block then
        proc = ProcUndumped.new(block)
        @worker.storage_set(:eval_proc,proc)
        code_args << " &->(*args){SmartNotebook::WorkerServer.Storage[:eval_proc].call(*args)} "
      end

      code = code + "(" + code_args.join(",")  +")" if code_args.size>0

      ret = eval (code)

      if block then
        @worker.storage_set(:eval_proc,nil)
        ProcUndumped.remove_proc(proc)
      end
      return ret
    end
  end

end