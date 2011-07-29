require 'set'

module DuplicityProgress
  class Duplicity
    @@super_dry = false

    def self.super_dry enable
      @@super_dry = enable
    end

    def initialize(args)
      @listeners = Set.new
      @args = args.dup
    end

    def add_listener listener
      @listeners.add listener
      self
    end

    def remove_listener listener
      @listeners.delete listener
      self
    end

    def run &block
      do_run false, false, block
    end

    def dry_run &block
      do_run true, false, block
    end

    def inject_run object, &block
      do_run false, true, block, object
    end

    def inject_dry_run object, &block
      do_run true, true, block, object
    end

    def parametrized_run dry, inject, object = nil, &block
      do_run dry, inject, block, object
    end

    private 
    def do_run dry, inject, block = nil, object = nil
      # listener for block
      block_listener = (block.nil? ? nil : BlockListener.new(block,inject,object))
      add_listener(block_listener) if block_listener

      args = prepare_args(dry, @args)
      IO.popen(args.join(" ")) do |io|
        io.each_line do |line|
          process_line line
        end
      end

      if block_listener
        return block_listener.result
      else
        return self
      end
    ensure
      remove_listener(block_listener) if block_listener 
    end

    def prepare_args dry, args
      before = ["duplicity","-vinfo"] + ((dry || @@super_dry)  ? ["--dry-run"] : [])
      after = ["2>&1"]
      before + args + after
    end

    def process_line line
      case line 
      when /^([ADM]) (.+)$/
        broadcast $1.to_sym, $2
      end
    end

    def broadcast kind, arg
      @listeners.each do |listener|
        if listener.respond_to?(:event)
          listener.event(kind, arg)
        end
      end
    end
  end
end
