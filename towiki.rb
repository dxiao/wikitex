#!/usr/bin/env ruby

=begin

    Converts a wikitex file into pure wiki markup, and prints it to the 
    specified file.

=end

print("Starting file conversion to wiki markup...\n")
print("File #{ARGV[0]} to file #{ARGV[1]}\n")
print("---\n")

source_file = File.open(ARGV[0], "r")
output_file = File.open(ARGV[1], "w")


$line_num    = 1
$mode        = :normal
$newline     = true

def debug (string)
    print("%3d: %s\n" % [$line_num, string])
end

def process_normal (source_line)
    $mode = :normal

    debug("     Normal  : " + source_line)

    if (math_index = source_line.index('$')) != nil
        if math_index == 0
            source_line = process_math(source_line[math_index+1..-1])
        elsif source_line[math_index-1] == '['[0]
            if math_index == 1
                source_line = process_mathbox(source_line[math_index+2..-1])
            else
                source_line = source_line[0..math_index-2] + 
                        process_mathbox(source_line[math_index+2..-1])
            end
        else
            source_line = source_line[0..math_index-1] +
                    process_math(source_line[math_index+1..-1])
        end
    end

    return source_line
end

def process_math (source_line)
    if $mode != :math
        prepend = '<math>'
    else
        continuation = true
        prepend = ''
    end
    $mode = :math

    debug("     Math    : " + source_line)

    if (not continuation) and source_line[0] == '$'[0]
        source_line = prepend + process_mulmath(source_line[1..-1])
    elsif (math_index = source_line.index('$')) != nil
        source_line = prepend + source_line[0..math_index-1] + '</math>' + \
                process_normal(source_line[math_index+1..-1])
    else
        source_line = prepend + source_line
    end

    return source_line
end

def process_mathbox (source_line)
    if $mode != :mathbox
        prepend = '<math>{\color{BrickRed}'
    else
        prepend = ''
    end
    $mode = :mathbox

    debug("     Mathbox : " + source_line)

    if (math_index = source_line.index('$$]')) != nil
        source_line = prepend + source_line[0..math_index-1] + \
            '}</math>' + process_normal(source_line[math_index+3..-1])
    else
        source_line = prepend + source_line
    end

    return source_line
end

def process_mulmath (source_line)
    if $mode != :mulmath
        prepend = '\begin{align}'
    else
        prepend = ''
    end
    $mode = :mulmath
    $newline = true

    debug("     Mulmath : " + source_line)

    if (math_index = source_line.index('$$')) != nil
        source_line = prepend + source_line[0..math_index-1] + \
            "\\end{align}</math>\n" + process_normal(source_line[math_index+2..-1])
    else
        source_line = prepend + source_line
    end

    return source_line
end

indent_stack= ""
indent_enum = false

#first_line  = source_file.readline.rstrip!
#debug("First line #{first_line}")
#output_file.write("<!-- #{first_line} -->\n")

source_file.each_line() { |source_line|

    source_line.rstrip!
    debug('')

    if $mode == :normal

        # if the line is
        if source_line == ""
            debug("...")
            output_file.write("\n")
            $newline = true;
            next
        end

        if source_line[0..0] == '='
            debug("=Section line")
            indent_stack = ''
            indent_enum  = false
            $newline     = true
            output_file.write(source_line + "\n")
            next
        end

        # figure out indentation level

        # line          0       0       f
        #   line        1       0-:     f
        # # number      0+1     0-#     t
        #   # number    1+1     1-##    t
        #   line        1+1     1-#     t
        #       line    3+1     3-#::   t
        #     # number  2+1     2-#:#   t
        # # number      0+1     0-#     t
        # 
        # line          0
        # : line        1
        # # number      1
        # ## number     2
        # #: line       2
        # #::: line     3
        # #:# number    3
        # # number      1

        indent_chars= source_line.match("^[ \t]+")
        if indent_chars
            indent_chars= indent_chars[0]
            indent_newd = indent_chars.count("\t") + indent_chars.count(' ')/4
            debug("    indent: count: #{indent_newd}, stack:#{indent_stack}")
        else
            indent_newd = 0
            indent_chars = ''
            if indent_stack
                $newline = true
            end
        end
        source_line.lstrip!
        indent_last = source_line[0]

        if indent_newd > indent_stack.length
            debug("Overindented by #{indent_newd-indent_stack.length}, padding")
            indent_out = indent_stack + ':'*(indent_newd - indent_stack.length)
            $newline = true
        elsif indent_newd == 0
            indent_out = ''
        else
            debug("Indenting #{indent_newd} out of #{indent_stack}.")
            indent_out = indent_stack[0..indent_newd-1]
            if indent_out != indent_stack.length
                $newline = true
            end
        end

        case source_line[0..0]
        when '*'
            indent_stack+= '*'
            indent_enum = true
            $newline     = true
        when '#'
            indent_stack+= '*'
            indent_enum = true
            $newline     = true
        else 
            indent_stack= indent_out
            if indent_out == ''
                indent_enum = false
            elsif indent_enum
                indent_out += ':'
            end
        end

        if ($newline)
            debug("Indent of #{indent_out} applied to new line")
            output_file.write("\n" + indent_out)
            $newline = false
        end

        source_line = process_normal(source_line)

    elsif $mode == :math
        source_line = process_math(source_line)
    elsif $mode == :mathbox
        source_line = process_mathbox(source_line)
    elsif $mode == :mulmath
        source_line = process_mulmath(source_line)
    end

    # if last two characters are \\, then set newline
    if $mode == :normal and source_line[-2..-1] == '\\\\'
        source_line = source_line[0..-3]
        $newline = true
        if not indent_enum
            source_line += "\n"
        end
        debug('\\\\Found newline sequence')
    end

    debug ("  Writing line: #{source_line}")
    output_file.write(source_line)

    $line_num += 1
}
