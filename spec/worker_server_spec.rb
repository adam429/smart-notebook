require 'spec_helper'

describe WorkerServer do
  describe "#eval" do
    it "assign local variables" do
      worker = WorkerServer.new()

      expect(worker.eval("a=1")).to eql(1)
      expect(worker.eval("a")).to eql(1)
      expect(worker.eval("b")).to eql(nil)
      expect(worker.eval("b=2")).to eql(2)
      expect(worker.eval("b")).to eql(2)
    end
  end

  describe "#add" do
    it "returns the sum of two numbers" do
      calculator = ->(a,b) { a+b }
      expect(calculator.call(5, 2)).to eql(7)
    end
  end
end