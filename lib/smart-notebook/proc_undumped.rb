require 'drb'

module SmartNotebook

  ProcList = []

  class ProcUndumped
    include DRb::DRbUndumped

    attr_accessor :proc

    def initialize(proc=nil)
      @proc = proc
      ProcList << self
    end

    def call(*args)
      proc.call(*args) if proc
    end

    def self.remove_proc(proc)
      ProcList.delete(proc)
    end
  end

end
