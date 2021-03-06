module SmartNotebook
  class OStream
    attr_accessor :buffer, :hook_proc

    def initialize(obj)
      @obj = obj
      @buffer = []
      @hook_proc = []
      @ref_count = {}
      @mutex = Mutex.new
    end

    def add_hook(proc)
      @mutex.synchronize do
        @ref_count[proc.hash] = (@ref_count[proc.hash] or 0) + 1
        @hook_proc << proc if not @hook_proc.include?(proc)
      end
    end

    def remove_hook(proc)
      @mutex.synchronize do
        @ref_count[proc.hash] = (@ref_count[proc.hash] or 0) - 1
        @hook_proc.delete(proc) if @ref_count[proc.hash] <= 0
      end
    end

    def delete_hook(proc)
      @mutex.synchronize do
        @ref_count[proc.hash] = 0
        @hook_proc.delete(proc)
      end
    end

    def puts(*lines)
      append_to_buffer(build_string { |sio| sio.puts(*lines) })
      begin
        @obj.puts(*lines)
      rescue =>e
      end
    end

    def putc(obj)
      append_to_buffer(build_string { |sio| sio.putc(obj) })
      begin
        @obj.putc(obj)
      rescue =>e
      end
    end

    def printf(*args)
      append_to_buffer(build_string { |sio| sio.printf(*args) })
      begin
        @obj.printf(*args)
      rescue =>e
      end
    end

    def write(data)
      append_to_buffer(build_string { |sio| sio.write(data) })
      begin
        @obj.write data
      rescue =>e
      end
    end
    alias_method :<<, :write
    alias_method :print, :write

    def writelines(lines)
      lines.each { |s| write(s) }
    end

    def isatty
      false
    end
    alias_method :tty?, :isatty

    def read(*args)
      raise IOError, 'not opened for reading'
    end
    alias_method :next, :read
    alias_method :readline, :read

    def flush
    end

    def close
      @buffer = []
    end

    def clean_buffer
      @buffer = []
    end

    # Called by irb
    def set_encoding(extern, intern)
      a = extern
    end

    private
    def build_string
      StringIO.open { |sio| yield(sio); sio.string }
    end

    def append_to_buffer(string)
      @buffer << string

      @hook_proc.dup.each do |proc|
        begin
          proc.call(string)
        rescue =>e
          begin
            delete_hook(proc)
          rescue => e
          end
        end
      end
    end
  end

end