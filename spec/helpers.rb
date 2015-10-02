# Ported from https://github.com/Operational-Transformation/ot.js/blob/master/test/helpers.js

# Test Helpers
class Helpers
  def random_string(n)
    str = ''

    n.times do
      if Random.rand < 0.15
        str += '\n'
      else
        str += (Random.rand(26) + 97).chr
      end
    end

    return str
  end

  def random_operation(str)
    operation = OT::TextOperation.new

    left = 0

    until left == 0
      left = str.length - operation.baseLength

      r = Random.rand

      l = 1 + Random.rand([left - 1, 20].min)

      if r < 0.2
        operation.insert(random_string(l))
      elsif r < 0.4
        operation.delete(l)
      else
        operation.retain(l)
      end
    end

    operation.insert('1' + random_string(10)) if Random.rand < 0.3

    return operation
  end
end
