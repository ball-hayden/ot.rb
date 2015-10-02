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

    loop do
      left = str.length - operation.base_length

      break if left == 0

      r = Random.rand

      length = 1
      length += Random.rand([left - 1, 20].min) if left > 1

      if r < 0.2
        operation.insert(random_string(length))
      elsif r < 0.4
        operation.delete(length)
      else
        operation.retain(length)
      end
    end

    operation.insert('1' + random_string(10)) if Random.rand < 0.3

    return operation
  end
end
