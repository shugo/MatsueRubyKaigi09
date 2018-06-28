# Rubyでつくるスレッド

author
: Shugo Maeda

institution
: Network Applied Communication Laboratory Ltd.

date
: 2018-06-30

theme
: lightning-night-black

allotted-time
: 5m

# やりたいこと

```ruby
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
```

# 継続

* 次の計算を表す
* グローバルなgotoみたいなもの
* 継続はRuby 1.8のスレッドの実装を使ってつくった
    * [ruby-dev:4083]
* では継続でスレッドをつくれるのでは？

# わかる人にはわかる説明

* Ruby 1.8のスレッドはスタックをコピーしてコンテキストスイッチのたびにスタックを書き戻す
* 継続も同じ仕組みで実装されている

# 継続の例

```ruby
require "continuation"
callcc {|c| $cont = c}
print "Hello, World!\n" 
$cont.call
```

# スレッドの作成

```ruby
module MinThread
  QUEUE = []

  def self.start(&block)
    QUEUE.push(block)
  end
```

# スレッドの実行

```ruby
def self.resume
  proc = QUEUE.shift
  if proc
    proc.call
  end
end
    
at_exit do
  MinThread.resume
end
```

# スレッドの切替

```ruby
def self.pass
  callcc do |c|
    start do
      c.call
    end
    resume
  end
end
```

# 動いた！

```ruby
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
```

# 何か違う

```ruby
MinThread.start do
  20.times do |i|
    puts "Thread#1: #{i}"
    sleep(0.1)
    MinThread.pass # これが必要
  end
end

MinThread.start do
  20.times do |i|
    puts "Thread#2: #{i}"
    sleep(0.1)
    MinThread.pass
  end
end
```

# 勝手にスレッドを切り替えたい

# TracePoint

* Ruby実行中のイベントをフック
* フックで切り替えればいいのでは？

# 実装

```ruby
at_exit do
  MinThread.set_next_switch_time
  TracePoint.trace(:line) do |tp|
    MinThread.schedule # 一定時間毎にThread.pass
  end
  MinThread.resume
end
```

# 1回しか切り替わらない！

# 理由

* フックの中ではTracePointが無効化される
* フック中で継続を呼ぶと無効化されたまま

# モンキーパッチ

```ruby
at_exit do
  MinThread.set_next_switch_time
  [Integer, String, Array, Hash, IO, File].each do |mod|
    mod.prepend Module.new {
      mod.instance_methods(false).each do |method|
        define_method(method) do |*args, &block|
          MinThread.schedule
          super(*args, &block)
        end
      end
    }
  end
  MinThread.resume
end
```

# デモ

# 課題

* IOなどでブロックすると全部止まる
    * IO#readなどをノンブロッキングIOで再実装すればいい
* すべてのスレッドが最後まで実行されない
    * キューが空になるまで実行するようにしたら、なぜか実行されすぎる

# まとめ

* スレッドはつくれる
