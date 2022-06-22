require 'pry'
require 'drb/drb'

module SmartNotebook
  In, Out = [nil], [nil]

  module EvalHistory
    def eval(code)
      b = eval_binding

      b.local_variable_set(:_ih, In)  unless b.local_variable_defined?(:_ih)
      b.local_variable_set(:_oh, Out) unless b.local_variable_defined?(:_oh)

      begin
        out = super
      rescue StandardError, ScriptError, SyntaxError  =>e
        raise_exception = true
        out = e
      end

      if SmartNotebook.store_history
        b.local_variable_set("_#{Out.size}", out)
        b.local_variable_set("_i#{In.size}", code)

        Out << out
        In << code

        b.local_variable_set(:___,  Out[-3])
        b.local_variable_set(:__,   Out[-2])
        b.local_variable_set(:_,    Out[-1])
        b.local_variable_set(:_iii, In[-3])
        b.local_variable_set(:_ii,  In[-2])
        b.local_variable_set(:_i,   In[-1])
      end

      raise out if raise_exception

      out
    end
  end

  class WorkerServer
    prepend EvalHistory

    @@storage = {}

    attr_accessor :stdout, :stderr, :eval_thread

    def self.Storage
      @@storage
    end

    def self.storage_set(key,value)
      @@storage[key] = value
    end

    def self.storage_args(key)
      ret= []
      @@storage[key].each do |v|
        ret << v
      end
      ret
    end

    def storage_set(key,value)
      WorkerServer.storage_set(key,value)
    end

    def editor_proc=(proc)
      @editor_remote_proc = proc

      if @editor_remote_proc then
        @editor_proc = proc do |file, line|
          new_code = @editor_remote_proc.call(File.read(file), line)
          File.write(file,new_code)
          nil
        end
      else
        @editor_proc = nil
      end

      @pry.editor = @editor_proc
    end

    def initialize(args = ARGV)
      @auto_restart = nil
      @worker_pid = nil
      @uri = (args[0] or SmartNotebook.worker_uri)
      @parent_pid = nil
      @stdout = OStream.new($stdout)
      @stderr = OStream.new($stderr)
      @eval_thread = []
      @storage = {}
      @editor_proc = nil
      @mutex = Mutex.new

      Pry.config.pager = false # Don't use the pager
      Pry.config.print = proc {|output, value|} # No result printing
      Pry.config.exception_handler = proc {|output, exception, _| }
      Pry.config.output = @stdout
      @pry = Pry.new(target: eval_binding)

      code = """
        self.define_method(:uri, ->() { '#{@uri}' })
      """
      @pry.eval(code)

      $stdout = @stdout
      $stderr = @stderr
    end

    def status
      return {}
    end

    def prompt(type)
      nesting_level = @pry.binding_stack.size - 1
      object = @pry.binding_stack.last.eval('self')

      if type==">" then
        return @pry.prompt.wait_proc.call(object,nesting_level,@pry)
      end
      if type=="*" then
        return @pry.prompt.incomplete_proc.call(object,nesting_level,@pry)
      end
    end


    def eval(code)
      @pry.evaluate_ruby (code)

      raise @pry.last_exception if @pry.last_result_is_exception?
      ret = @pry.last_result
      @pry.last_result = nil

      ret_inspect = ret.inspect

      ret = ret_inspect if (ret_inspect =~ /#<[^:]+:0x[0-9a-f]+>/) or ret.class == Class

      return ret
    end

    def find_command(code)
      !(@pry.commands.find_command(code) == nil)
    end

    def run_command(code, output_proc=nil, system_proc = nil)
      @pry.config.system, @old_system = system_proc, @pry.config.system
      @stdout.add_hook(output_proc) if output_proc

      @pry.run_command(code)

      @stdout.remove_hook(output_proc) if output_proc
      @pry.config.system = @old_system
    end

    def eval_await(code, output_proc=nil, result_proc=nil)
      @stdout.add_hook(output_proc) if output_proc
      @stderr.add_hook(output_proc) if output_proc

      begin
        ret = self.eval(code)
      rescue StandardError, ScriptError, SyntaxError  =>e
        puts "#{e.class}: #{e.to_s}"
        puts e.backtrace
      ensure
        result_proc.call(ret) if result_proc
        output_proc.call(nil) if output_proc
        @stdout.remove_hook(output_proc) if output_proc
        @stderr.remove_hook(output_proc) if output_proc
      end

      ret
    end

    def eval_async(code, output_proc=nil, result_proc=nil)
      @stdout.add_hook(output_proc) if output_proc
      @stderr.add_hook(output_proc) if output_proc

      thread = Thread.new do
        begin
          ret = self.eval(code)
        rescue StandardError, ScriptError, SyntaxError  =>e
          puts "#{e.class}: #{e.to_s}"
          puts e.backtrace
        ensure

          begin
            result_proc.call(ret) if result_proc
          rescue => e
          end
          begin
            output_proc.call(nil) if output_proc
          rescue => e
          end

          @stdout.remove_hook(output_proc) if output_proc
          @stderr.remove_hook(output_proc) if output_proc
        end

        ret
        @eval_thread.delete(Thread.current)
      end
      @eval_thread << thread

      return thread
    end

    def complete(code)
      @pry.complete(code)
    end

    def restart()
      puts "Restart Worker #{Process.pid}"
      DRb.stop_service
      @mutex.synchronize do
        @eval_thread.each { |thread| Thread.kill }
        @eval_thread = []
      end
      Process.kill("TERM", Process.pid)
    end

    def shutdown()
      if @parent_pid then
        puts "Shutdown Auto Restart #{@parent_pid}"
        Process.kill("TERM", @parent_pid)
      end

      puts "Shutdown Worker #{Process.pid}"
      DRb.stop_service
      Process.kill("TERM", Process.pid)
    end

    def auto_restart(option={})
      @parent_pid = Process.pid

      pid_alive = false
      loop do
        trap('TERM') do
          Process.kill("TERM", @worker_pid)
          exit 0
        end

        pid_alive = `ps -p #{@worker_pid}`.split("\n").size>1 if @worker_pid

        if not pid_alive then
          puts "Auto Restart : Start Worker"

          start_worker(@uri, fail: ->(e) {
            puts "Start Worker failed #{e.inspect}"
            puts e.backtrace
            Process.kill("TERM", @parent_pid)
          })
        end

        sleep(0.1)
      end

    end

    private

    def start_worker(uri,option={})
      @worker_pid = Process.fork do
        trap('TERM') do
          puts "Signal TERM shutdown the server #{@uri}"
          exit 0
        end

        begin
          worker = WorkerServer.new()
          DRb.start_service(uri, {worker:worker}, SmartNotebook.drb_config)
          DRb.thread.join
        rescue =>e
          option[:fail].call(e) if option[:fail]
        end
      end
      Process.detach(@worker_pid)
      puts "Start Worker #{@uri} | pid = #{@worker_pid}"
    end

    def eval_binding
      return TOPLEVEL_BINDING
    end
  end
end

