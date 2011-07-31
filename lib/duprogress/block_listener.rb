module DuplicityProgress
  class BlockListener
    def initialize block, inject = false, memo = nil
      @block = block
      @memo = memo 
      @inject = inject
    end

    def result
      @memo
    end

    def event e 
      if @inject
        @memo = @block.call(@memo, e)
      else
        @memo = @block.call(e)
      end
    end
  end
end
