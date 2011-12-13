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

    def add_listener listener, options={}
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

      # log pipe
      log_r,log_w = IO.pipe
      begin
        args = prepare_args(dry, log_w.fileno, @args)
        Kernel.fork {
          # mute stdout and stderr to /dev/null
          [$stdout,$stderr].each{|io| io.reopen(File.new("/dev/null","w"))}
          # close log pipe reading-end
          log_r.close

          Kernel.exec(*args)
          throw "Kernl.exec error"
        }
        # close log-pipe writing-end
        log_w.close

        @event = nil
        log_r.each_line do |line|
          process_line line
        end
        broadcast

      ensure
        log_r.close
        log_w.close unless log_w.closed?
      end

      if block_listener
        return block_listener.result
      else
        return self
      end
    ensure
      remove_listener(block_listener) if block_listener 
    end

    def prepare_args dry, logfd, args
      before = ["duplicity","-vdebug","--log-fd=#{logfd}"] + ((dry || @@super_dry)  ? ["--dry-run"] : [])
      after = []
      before + args + after
    end

    def process_line line
      case line
      when /^$/
        broadcast

      when /^(NOTICE|INFO|WARNING|DEBUG|ERROR) ([0-9]+) (.+)$/
        @event = Event.new($1.to_sym, $2.to_i, $3)
      
      when /^(NOTICE|INFO|WARNING|DEBUG|ERROR) ([0-9]+)[ ]*$/
        @event = Event.new($1.to_sym, $2.to_i)

      when /^([^\.].*)$/
        m = $1
        if @event.arg.nil?
          @event.arg = m
        else
          @event.arg.concat("\n").concat(m)
        end

      when /^\. (.*)$/
        m = $1
        if @event.message.nil?
          @event.message = $1
        else
          @event.message.concat("\n").concat(m)
        end

      else
        throw "unmatched line"
      end
    end

    def broadcast
      return if @event.nil?
      @event.freeze
      @listeners.each do |listener|
        if listener.respond_to?(:event)
          listener.event(@event)
        end
      end
    ensure
      @event = nil
    end
  end
end
