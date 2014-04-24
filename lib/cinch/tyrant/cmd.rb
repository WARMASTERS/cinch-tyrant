module Cinch; module Tyrant

  Cmd = Struct.new(:category, :command, :args, :visible_f, :help) {
    def visible?(m)
      return true if self.visible_f.is_a?(TrueClass)
      return false if self.visible_f.is_a?(FalseClass)
      self.visible_f.call(m)
    end

    def to_s
      arg = self.args.empty? ? '' : ' ' + self.args
      self.command + arg + ': ' + self.help
    end
  }

end; end
