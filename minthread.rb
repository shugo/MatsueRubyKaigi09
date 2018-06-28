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
    if proc
      proc.call
    end
  end
end

at_exit do
  MinThread.resume
end

MinThread.start do
  20.times do |i|
    puts "Thread#1: #{i}"
    sleep(0.1)
    MinThread.pass
  end
end

MinThread.start do
  20.times do |i|
    puts "Thread#2: #{i}"
    sleep(0.1)
    MinThread.pass
  end
end
