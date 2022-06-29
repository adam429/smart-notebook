require 'open3'

module SmartNotebook
  module SaveHistory
    def backup_history
      change = Readline::HISTORY.to_a.last

      if  not (/^\s*$/ =~ change) then
        current_history = []
        if File.exist?(".smart_notebook_rc_history")
          open(".smart_notebook_rc_history") do |f|
            f.each {|l| current_history << l.chomp}
          end
        end

        current_history << change

        open(".smart_notebook_rc_history","w") do |f|
          hist = current_history.to_a
          f.puts(hist[-256..-1] || hist)
        end
      end
    end

    def restore_history
      if File.exist?(".smart_notebook_rc_history")
        open(".smart_notebook_rc_history") do |f|
          f.each {|l| Readline::HISTORY << l.chomp}
        end
      end
    end

  end

  class CLI
    prepend SaveHistory

    def initialize(args = ARGV)
      cli_url_p = 0
      begin
        DRb.start_service(SmartNotebook.cli_uri[cli_url_p] ,nil, SmartNotebook.drb_config)
        puts "Start SmartNotebook at #{SmartNotebook.cli_uri[cli_url_p] } "
      rescue =>e
        if cli_url_p < SmartNotebook.cli_uri.size then
          cli_url_p = cli_url_p + 1
          retry
        end
      end

      @uri = (args[0] or SmartNotebook.worker_uri)
      @client = RemoteWorker.new(@uri)
      @code = ""
      @prompt = ">"
    end

    def prompt
      if @hide_prompt then
        return ""
      else
        begin
          return "#{@uri} #{@client.prompt(@prompt)} "
        rescue
          # when client connection is lost, show default prompt
          return "#{@uri} #{@prompt}"
        end
      end
    end

    # callback when thread end, show prompt
    def refresh_prompt
      @hide_prompt = false
    end

    def output_proc
      @output_proc = ProcUndumped.new(->(x){
        if x then
          print x
        else
          # last output of each thread is nil, when nil callback refresh_prompt
          refresh_prompt
        end
      }) if @output_proc==nil

      @output_proc
    end

    def result_proc
      @result_proc = ProcUndumped.new(->(x) { puts "=> #{x}" }) if @result_proc==nil
      @result_proc
    end

    def editor_proc
      @editor_proc = ProcUndumped.new(->(initial_content, line) { Pry::Editor.new(Pry.new).edit_tempfile_with_content(initial_content, line) }) if @editor_proc==nil
      @editor_proc
    end

    def system_proc
      @system_proc = ProcUndumped.new(proc do |output, cmd, _|
        status = nil
        Open3.popen3 cmd do |stdin, stdout, stderr, wait_thr|
          stdin.close # Send EOF to the process

          until stdout.eof? and stderr.eof?
            if res = IO.select([stdout, stderr])
              res[0].each do |io|
                next if io.eof?
                output.write io.read_nonblock(1024)
              end
            end
          end

          status = wait_thr.value
        end

        unless status.success?
          output.puts "Error while executing command: #{cmd}"
        end
      end) if @system_proc==nil

      @system_proc

    end

    def run
      comp = proc { |s| @client.worker.complete(s) }
      Readline.completion_append_character = ""
      Readline.completion_proc = comp

      # trap ctrl-c to exit from incomplete input
      trap("INT") do
        @code = ""
        @prompt = ">"
        puts "\n"
        refresh_prompt
      end

      restore_history
      while buf = Readline.readline(self.prompt, true)
        begin
          refresh_prompt
          backup_history
          if buf=="exit" or buf==".exit" then
            # exit
            break

          elsif buf=~/^connect (.+)/ then
            # connect
            uri = $1
            @uri = @client.connect(@client.eval($1))

          elsif buf=="restart" then
            # restart
            @client.restart()

          elsif buf=="" then
            # ignore empty input

          elsif @client.find_command(buf) then
            # run remote command - .ls
            @client.run_command(buf, editor_proc, output_proc, nil)
          elsif @client.find_command(buf.gsub(/^\//,"\.")) then
            # run local command - /ls
            @client.run_command(buf.gsub(/^\//,"\."), editor_proc, output_proc, system_proc)
          else
            # deal with code input
            @code = @code + buf + "\n"

            if Ripper.sexp(@code) == nil
              @prompt = "*"
            else
              @prompt = ">"
            end

            if @prompt == ">" then
              # when code is complete, eval code
              @hide_prompt = true

              @client.eval_async(@code,output_proc,result_proc)
              # @client.eval_await(@code,output_proc,result_proc)
              @code = ""
            end
          end
          restore_history
        rescue StandardError, ScriptError => e
          puts "#{e.inspect}"
          puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
        end
      end

    end
  end

end