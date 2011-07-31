module DuplicityProgress
  class Event
    def initialize major, minor, arg = nil
      @major = major
      @minor = minor
      @arg = arg
      @message = nil
    end

    def message= m
      @message = m
    end

    def message
      @message
    end

    def major
      @major
    end

    def minor
      @minor
    end

    def arg= a
      @arg = a
    end

    def arg
      @arg
    end
  end

end
