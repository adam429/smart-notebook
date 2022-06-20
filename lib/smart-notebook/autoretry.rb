module SmartNotebook

  class AutoRetry
    def catch(fix_proc=nil)
      begin
        yield
      rescue => e
        if (retry_count = (retry_count or 0) + 1)<10 then
          puts "#{e.inspect} - AutoRetry #{retry_count}th retry - sleep #{0.005*2**retry_count} s"
          puts e.backtrace
          sleep(0.005*2**retry_count)
          fix_proc.call if fix_proc
          retry
        else
          raise e
        end
      end
    end
  end

end
