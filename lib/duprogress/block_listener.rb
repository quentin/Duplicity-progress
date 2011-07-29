module DuplicityProgress
  class BlockListener
    def initialize block, inject = false, object = nil
      @block = block
      @result = object
      @inject = inject
    end

    def result
      @result
    end

    def event kind, arg
      if @inject
        @result = @block.call(@result, kind, arg)
      else
        @result = @block.call(kind, arg)
      end
    end
  end
end
