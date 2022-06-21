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
      @obj.puts(*lines)
    end

    def printf(*args)
      append_to_buffer(build_string { |sio| sio.printf(*args) })
      @obj.printf(*args)
    end

    def write(data)
      append_to_buffer(build_string { |sio| sio.write(data) })
      @obj.write data
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
          delete_hook(proc)
        end
      end
    end
  end

end