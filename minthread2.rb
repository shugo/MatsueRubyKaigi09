require "continuation"

module MinThread
  QUEUE = []

  def self.start(&block)
    QUEUE.push(block)
  end

  def self.pass
    callcc do |c|
      start do
        c.call
      end
      resume
    end
  end

  def self.resume
    proc = QUEUE.shift
    @in_schedule = false
    if proc
      proc.call
    end
  end

  SWITCH_INTERVAL = 0.5

  def self.set_next_switch_time
    @next_switch_time = Time.now + SWITCH_INTERVAL
  end

  @in_schedule = false

  def self.schedule
    return if @in_schedule
    @in_schedule = true
    begin
      if Time.now >= @next_switch_time
        set_next_switch_time
        MinThread.pass
      end
    ensure
      @in_schedule = false
    end
  end
end

at_exit do
  MinThread.set_next_switch_time
  TracePoint.trace(:line) do |tp|
    MinThread.schedule
  end
  MinThread.resume
end

MinThread.start do
  20.times do |i|
    puts "Thread#1: #{i}"
    sleep(0.1)
  end
end

MinThread.start do
  20.times do |i|
    puts "Thread#2: #{i}"
    sleep(0.1)
  end
end
