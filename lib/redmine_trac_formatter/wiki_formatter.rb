require 'rubygems'
require 'oniguruma'

module RedmineTracFormatter
  class WikiFormatter

    attr_accessor :text

    # Create the object
    def initialize(text = "")
      @text = text
    end

    def to_html(&block)
      return "" unless /\S/m =~ @text

      return parse_trac_wiki

    rescue RuntimeError => e
      return "<pre>#{e.message}</pre>"
    end

    def parse_trac_wiki
      text = @text.dup

      ### PARAGRAPHS
      # TODO: verify that this behavior is valid - opening and closing entire wikitext with p tags
      text = "<p>\n#{text}\n</p>"
      text.gsub!(/\r\n/, "\n") # remove any CRLF with just LF
      text.gsub!(/\r/, "\n")   # now replace CR by itself with LF
      # || \ (newline) || -> '||"
      text.gsub!(/\|\|\s*\\\s*\n\s*\|\|/, "||")   # now replace multiline table rows

      formatted = ""
      parse_line = true
      block_ending = ""
      next_ending = ""
      tmp_buffer = ""
      @list_levels = []
      @citation_level = 0

      text.each { |t|
        # look for things that end temp buffering blocks

        # PREFORMATTED TEXT (END MULTI-LINE BLOCK)
        # TODO: lookbehind for negation !
        if !parse_line && block_ending == "}}}" && t =~ /^(.*?)\}\}\}(.*)$/
          parse_line = true # start normal parsing again
          block_ending = ""
          t = $2 # only parse stuff after }}}
          formatted += "#{tmp_buffer}#{$1}</pre>" # add buffer and ending to formatted text
          tmp_buffer = '' # reset buffer
        end

        # TABLES LINE CONTINUES
        if !parse_line && block_ending == "||"
          # we were parsing a table
          if t =~ /^\|\|.*/
            # another table line
            tmp_buffer += parse_table_line(t)
            next
          else
            formatted += tmp_buffer + "</tbody>\n</table>\n"
            parse_line = true
            tmp_buffer = ""
            block_ending = ""
          end
        end

        # quick hack: BLOCKQOUTE is CITATION
        if !parse_line && block_ending == "BQ"
           if  is_blockquote_line(t)
                formatted += parse_one_line_markup(t)
                next
           else
                parse_line = true
                block_ending = ''
                formatted += "\n</blockquote>\n";
           end
        end

        # continuation of <dl><DD>
        if !parse_line && block_ending == "DD"
          if t =~ /^\s+/
            formatted += parse_one_line_markup(t)
            next
          else
            parse_line = true
            block_ending = ""
            formatted += "</dd></dl>"
          end
        end
        ### LISTS (END MULTI-LINE BLOCK)
        if !parse_line && block_ending == "LI"
          if is_list_line(t)
            formatted += parse_list_line(t)
            next
          elsif is_list_continuation(t)
            formatted += parse_one_line_markup(t)
            next
          else
            parse_line = true
            block_ending = ""
            formatted += end_list(true)
          end
        end

        ### CITATION (END MULTI-LINE BLOCK)
        if !parse_line && block_ending == "CI"
          if is_citation_line(t)
            formatted += parse_citation_line(t)
            next
          else
            parse_line = true
            block_ending = ""
            formatted += citation_level_to(0)
          end
        end

        if !parse_line
          tmp_buffer += "#{t}"
          next
        end

        # remove the newline from the end of our lines:
        t.chomp!

        ### PARAGRAPHS (empty line becomes end of paragraph and start of new paragraph)
        # TODO: duplicate new lines should probably not open and close empty paragraphs
        if "" == t.strip
          formatted.chomp!
          formatted += "</p>\n<p>"
          next
        end

        ### PREFORMATTED TEXT
        #{{{
        #multiple lines, ''no wiki''
        #      white space respected
        #}}}
        #<pre class="wiki">multiple lines, ''no wiki''
        #      white space respected
        #</pre>

        # Now do multi-line preformatted text parsing
        # TODO: lookbehind for negation !
        if t =~ /^\{\{\{$/
          parse_line = false   # don't parse lines until we find the end
          block_ending = "}}}" # so our code above knows we're buffering preformatted text
          t = "" # parse everything before {{{ just like you normally would
          tmp_buffer = "<pre class=\"wiki\">\n" # store everything after in a temp buffer until }}} found
        end

        ### TABLES
        #||= Table Header =|| Cell ||
        #||||  (details below)  ||
        #<table class="wiki">
        #<tr><th> Table Header </th><td> Cell
        #</td></tr><tr><td colspan="2" style="text-align: center">  (details below)
        #</td></tr></table>
        #
        if t =~ /^\|\|(.*)\|\|\s*$/
          # TODO: allow for trailing backslash to continue tr on next line
          parse_line = false   # don't parse lines until we find the end
          block_ending = "||"  # so our code above knows we're buffering a table
          t = "" # don't parse anything else on this line
          tmp_buffer = "<table class=\"wiki\">\n<tbody>\n" # start the table
          tmp_buffer += parse_table_line($1)
        end

        ### LISTS
        #* bullets list
        #  on multiple lines
        #  1. nested list
        #    a. different numbering
        #       styles
        #
        #<ul><li>bullets list
        #on multiple lines
        #<ol><li>nested list
        #<ol class="loweralpha"><li>different numbering
        #styles
        #</li></ol></li></ol></li></ul>
        if is_list_line(t)
          parse_line = false   # don't parse lines until we find the end
          block_ending = "LI"  # so our code above knows we're buffering a list
          formatted +=  parse_list_line(t)
          t = "" # don't parse anything else on this line
        end


        ### DEFINITION LISTS
        # TODO:
        # term:: definition on
        #        multiple lines
        # <dl><dt>(term)</dt><dd>definition on
        #        multiple lines</dd></dl>
        if t =~ /^([^:]+):: (.*)/
          term, rest = $1,$2
          formatted += "<dl><td>#{term}</td><dd>"
          formatted += parse_one_line_markup(rest)
          parse_line = false   # don't parse lines until we find the end
          block_ending = "DD"  # so our code above knows we're buffering a list
          t = "" # don't parse anything else on this line
        end

        ### BLOCKQUOTES
        # TODO:
        #  if there's some leading
        #  space the text is quoted
        #<blockquote>
        #<p>
        #if there's some leading
        #space the text is quoted
        #</p>
        #</blockquote>
        if is_blockquote_line(t)
          parse_line = false   # don't parse lines until we find the end
          block_ending = "BQ"  # so our code above knows we're buffering a list
          formatted += "<blockquote>\n"
          formatted += parse_one_line_markup(t)
          t = "" # don't parse anything else on this line
        end

        ### DISCUSSION CITATIONS
        # TODO:
        #>> ... (I said)
        #> (he replied)
        #<blockquote class="citation">
        #<blockquote class="citation">
        #<p>
        #... (I said)
        #</p>
        #</blockquote>
        #<p>
        #(he replied)
        #</p>
        #</blockquote>
        #
        if is_citation_line(t)
          parse_line = false   # don't parse lines until we find the end
          block_ending = "CI"  # so our code above knows we're buffering a list
          formatted += parse_citation_line(t)
          t = "" # don't parse anything else on this line
        end
        ### MACROS
        # TODO: probably won't do this unless redmine has it built in
        #[[MacroList(*)]] becomes a list of all available macros
        #[[Image?]] becomes help for the Image macro
        #

        ### PROCESSORS AND CODE FORMATTING
        # TODO:
        #{{{
        ##!div style="font-size: 80%"
        #Code highlighting:
        #  {{{#!python
        #  hello = lambda: "world"
        #  }}}
        #}}}
        #<div style="font-size: 80%" class="wikipage"><p>
        #Code highlighting:
        #</p>
        #<div class="code"><pre>hello <span class="o">=</span> <span class="k">lambda</span><span class="p">:</span> <span class="s">"world"</span>
        #</pre></div></div>
        #

        ### COMMENTS
        # TODO: (the following gets removed completely
        #{{{#!comment
        #Note to Editors: ...
        #}}}
        #

        t = parse_one_line_markup(t)
        formatted += "#{t}\n"
      } # end of each block over string lines

      return formatted
    end

    def parse_table_line(t)
      t = t.chomp.gsub(/^\s*\|\|(.*)\|\|\s*$/, '\1')
      t.gsub!('||', '<td>')
      ret = ""
      colspan = 1

      t.each("<td>") { |cell|
        #cell.gsub!(/\|\|\s*$/, '')
        cell.gsub!(/<td>\s*$/, '')
        boundary = "td"
        style = ""
        contents = cell
        if cell =~ /^=(.*)=$/
          boundary = "th"
          contents = $1
        end

        if contents =~ /^\S/
          style=" style='text-align: left'"
        elsif contents =~ /.*\S$/
          style=" style='text-align: right'"
        elsif contents =~ /^\s\s.*\s\s$/
          # two spaces on each side => center
          style=" style='text-align: center'"
        end
        if contents ==  ''
           colspan += 1
        else
          colspantxt = colspan > 1 ? " colspan='#{colspan}'": ''
          contents = parse_one_line_markup(contents)
          ret += "<#{boundary}#{style}#{colspantxt}>#{contents}</#{boundary}>"
          colspan = 1
        end
      }
      return "<tr>#{ret}</tr>\n"
    end

    def is_citation_line(t)
      return t =~ /^\s*>/
    end

    def is_blockquote_line(t)
      return t =~ /^\s+/
    end


    def is_list_continuation(t)
      return t =~ /^\s+\S/
    end
    def is_list_line(t)
      #return t =~ /^(\s*)(-|\*|[-0-9a-zA-Z])\.? (.*)/
      return t =~ /^\s*(-|\*|[0-9a-zA-Z]\.)\s/
    end

    def parse_citation_line(t)
      t =~ /^([\s>]*)(.*)/
      qq = $1
      rest_line = $2

      return citation_level_to(qq.count('>')) + parse_one_line_markup(rest_line) 

    end

    def citation_level_to(n)
        ret = ''
        while @citation_level < n
          ret += ("  " * @citation_level) + "<blockquote>\n"
          @citation_level += 1
        end
        while @citation_level > n
          @citation_level -= 1
          ret += ("  " * @citation_level) + "</blockquote>\n"
        end
        return ret
    end

    def parse_list_line(t)
      #* bullets list
      #  on multiple lines
      #  1. nested list
      #    a. different numbering
      #       styles
      #
      #<ul><li>bullets list
      #on multiple lines
      #<ol><li>nested list
      #<ol class="loweralpha"><li>different numbering
      #styles
      #</li></ol></li></ol></li></ul>
      t.chomp!
      ret = ""
      t =~ /^(\s*)(-|\*|[0-9a-zA-Z])\.? (.*)/
      spaces = $1
      num_spaces = $1.length
      type = $2
      contents = $3
      last_num_spaces = @list_levels.empty? ? 0 : @list_levels.last[0]
      started_new = false

      if @list_levels.empty? || last_num_spaces < num_spaces
        started_new = true
        # starting a new (or deeper) level
        if type =~ /-|\*\.?/
          @list_levels.push([ num_spaces, "ul" ])
          ret += "\n#{spaces}<ul>\n"
        elsif type =~ /[0-9]\.?/
          @list_levels.push([ num_spaces, "ol" ])
          ret += "\n#{spaces}<ol>\n"
        elsif type =~ /[i]\.?/
          @list_levels.push([ num_spaces, "loweralpha" ])
          ret += "\n#{spaces}<ol type='i' class='loweralpha'>\n"
        elsif type =~ /[I]\.?/
          @list_levels.push([ num_spaces, "loweralpha" ])
          ret += "\n#{spaces}<ol type='I' class='loweralpha'>\n"
        elsif type =~ /[a-z]\.?/
          @list_levels.push([ num_spaces, "loweralpha" ])
          ret += "\n#{spaces}<ol type='a' class='loweralpha'>\n"
        elsif type =~ /[A-Z]\.?/
          @list_levels.push([ num_spaces, "upperalpha" ])
          ret += "\n#{spaces}<ol type='A' class='upperalpha'>\n"
        end
      end

      if !started_new
        ret += (" " * @list_levels.last[0]) + "  </li>\n"
      end

      while last_num_spaces > num_spaces
        # ended previous list
        ret += (" " * last_num_spaces) + end_list
        last_num_spaces = @list_levels.empty? ? 0 : @list_levels.last[0]
      end

      contents = parse_one_line_markup(contents)
      ret += "#{spaces}  <li>#{contents}\n"

      return ret
    end

    def end_list(all = false, ret = "")
      num_spaces, list_type = @list_levels.pop
      if all
        ret += (" " * num_spaces) + "  </li>\n"
      end
      if list_type == "ul"
        ret += "</ul>\n"
      else
        ret += "</ol>\n"
      end
      if !@list_levels.empty?
        # this was a nested list, so add ending li tag
        ret += (" " * @list_levels.last[0]) + "  </li>\n"
      end
      if all
        while !@list_levels.empty?
          ret = end_list(false, ret)
        end
      end
      return ret
    end

    def parse_one_line_markup(t)

      ### MONOSPACE
      # `this text`
      # <tt>this text</tt>
      # {{{this text}}}
      # <tt>this text</tt>
      if t =~ /(.*?)([^!]?)`(.+?[^!]?)`(.*)/ || t =~ /(.*?)([^!]?)\{\{\{(.+?[^!]?)\}\}\}(.*)/
        start, tt, rest  =  "#{$1}#{$2}", "<tt>#{$3}</tt>", $4
        start = parse_one_line_markup(start)
        rest  = parse_one_line_markup(rest)
        return start + tt + rest
      end

      # FONT STYLES
      # Wikipedia style:
      Oniguruma::ORegexp.new('(?<!!)\'\'\'\'\'(.+?)(?<!!)\'\'\'\'\'').gsub!(t, '<strong><em>\1</em></strong>')

      # Bold:
      Oniguruma::ORegexp.new('(?<![\'!])\'\'\'(.+?)(?<![\'!])\'\'\'').gsub!(t, '<strong>\1</strong>')
      Oniguruma::ORegexp.new('(?<!!)\*\*(.+?)(?<!!)\*\*').gsub!(t, '<strong>\1</strong>')

      # Underline:
      Oniguruma::ORegexp.new('(?<!!)\_\_(.+?)(?<!!)\_\_').gsub!(t, '<u>\1</u>')

      # Italics:
      Oniguruma::ORegexp.new('(?<![\'!])\'\'(.+?)(?<![\'!])\'\'').gsub!(t, '<em>\1</em>')
      Oniguruma::ORegexp.new('(?<![!:])//(.+?)(?<!!)//').gsub!(t, '<em>\1</em>')

      # ~~strike~~ ,,sub,, and ^sup^

      Oniguruma::ORegexp.new('(?<![!:])~~(.+?)(?<!!)~~').gsub!(t, '<strike>\1</strike>')
      Oniguruma::ORegexp.new('(?<![!:])\^(.+?)(?<!!)\^').gsub!(t, '<sup>\1</sup>')
      Oniguruma::ORegexp.new('(?<![!:]),,(.+?)(?<!!),,').gsub!(t, '<sub>\1</sub>')

      # inline {{{ code }}}  or `code`
      #Oniguruma::ORegexp.new('(?<![!:])\{\{\{(.+?)(?<!!)\}\}\}').gsub!(t, '<code>\1</code>')
      #Oniguruma::ORegexp.new('(?<![!:])`(.+?)(?<!!)`').gsub!(t, '<code>\1</code>')

      # HEADINGS
      Oniguruma::ORegexp.new('(?<!!)===== (.+?)(?<!!) =====').gsub!(t, '<h5>\1</h5>')
      Oniguruma::ORegexp.new('(?<!!)==== (.+?)(?<!!) ====').gsub!(t, '<h4>\1</h4>')
      Oniguruma::ORegexp.new('(?<!!)=== (.+?)(?<!!) ===').gsub!(t, '<h3>\1</h3>')
      Oniguruma::ORegexp.new('(?<!!)== (.+?)(?<!!) ==').gsub!(t, '<h2>\1</h2>')
      Oniguruma::ORegexp.new('(?<!!)= (.+?)(?<!!) =').gsub!(t, '<h1>\1</h1>')

      ### MISCELLANEOUS
      #Line [[br]] break
      #Line <br /> break
      t.gsub!(/\[\[[Bb][Rr]\]\]/, '<br />')
      # Oniguruma::ORegexp.new('(?<!!)\[\[[Bb][Rr]\]\]').gsub!(t, '<br />')
      #Line \\ break
      #Line <br /> break
      t.gsub!(/\\\\/, '<br />')
      # Oniguruma::ORegexp.new('(?<!!)\\\\\\').gsub!(t, '<br />')
      #----
      #<hr />
      t.gsub!(/^[\s]*----[\s]*$/, '<hr />')

      ### IMAGES
      #[[Image(link)]]
      #<a style="padding:0; border:none" href="/chrome/site/../common/trac_logo_mini.png"><img src="/chrome/site/../common/trac_logo_mini.png" alt="trac_logo_mini.png" title="trac_logo_mini.png" /></a>
      Oniguruma::ORegexp.new('(?<!!)\[\[Image\((.*?)(, (.*?))?\)\]\]').gsub!(t, '<a style="padding: 0; border: none" href="\1" \3><img src="\1" \3 /></a>')

      # LINKS
      # for external links, we directly create the link tags.  But for other (redmine) links,
      # rather than directly creating and parsing links we allow redmine to do it.
      # All we do for these is translate trac link syntax into redmine link syntax
      # Examples:
      # TRAC: [wiki:SomePage Some Page on the Wiki][[br]]
      # RM:   [[SomePage|Some Page on the Wiki]]<br />
      # TRAC: [wiki:SomePage][[br]]
      # RM:   [[SomePage]]<br />
      # TRAC: #7112 or ticket:7112 both link to issue number 7112[[br]]
      # RM:   #7112 or #7112 both link to issue number 7112<br />
      # TRAC: {40} or report:40 both link to report forty[[br]]
      # RM:   I don't know if there is an equivalent.
      # TRAC: r123 or [123] or changeset:123 all link to changeset number 123[[br]]
      # RM:   r123 or r123 or r123 all link to changeset number 123<br />
      # TRAC: attachment:example.tgz links to an attachment on this page[[br]]
      # RM:   NO CHANGE
      # source:trunk/README links to the README file in trunk[[br]]
      # RM:   NO CHANGE
      # source:trunk/README@200#L25 links to version 200, line 25 of the same file[[br]]
      # RM:   NO CHANGE

      # recognize creole style:
      #   [[CONTENT]] --> [CONTENT]
      Oniguruma::ORegexp.new('(?<!!)\[\[([^\]]*)\]\]').gsub!(t) do
        %([#{$1}])
      end

      # recognize raw URL:
      #   http://example.com
      #   https://example.com
      #   ftp://example.com
      #   www.example.com
      #   ==> [http://example.com]
      Oniguruma::ORegexp.new('(?m:(^|\s)(https?://|s?ftps?://|www\.)(\S+))').gsub!(t) do
        #%(I_<a class="EXternal" href="#{$1}">#{$1}</a>_I)
        space, proto, rest = $1, $2, $3
        if proto == 'www.'
          %(#{space}[http://#{proto}#{rest} #{proto}#{rest}])
        else
          %(#{space}[#{proto}#{rest}])
        end
      end

      # First, external links that we create link tags for ourselves:
      # TRAC: [http://github.com GitHub]
      # RM:   "GitHub":http://github.com<br />
      # TRAC: [http://github.com/jthomerson/redmine_trac_formatter_plugin Redmine Trac Formatter Plugin][[br]]
      # RM:   "Redmine Trac Formatter Plugin":[http://github.com/jthomerson/redmine_trac_formatter_plugin<br />
      Oniguruma::ORegexp.new('(?<!!)\[((?:https?://)|(?:s?ftps?://)|(?:www\.))(\S+)\s?(.*?)\]').gsub!(t) do
        text = ($3 == "" || $3 == nil) ? "#{$1}#{$2}" : $3
        %(<a class="external" href="#{$1}#{$2}">#{text}</a>)
      end

      # Now, other [bracketed] links:
      t.gsub!(/(.?)\[([a-z]+:)?([^\s\]]+)\s?(.*?)\]/) do
        all, negator, type, dest, text = $&, $1, $2, $3, $4
        # For testing: puts "negator: #{negator}, type: #{type}, dest: #{dest}, text: #{text}, all: |#{all}|"
        type = (type == nil ? "" : type.gsub(/:$/, ''))
        result = ""
        if negator =~ /!/
          # user didn't want this one to be a link
          result = all
        end

        # The following link types don't appear to allow descriptive text in redmine
        # and just become "attachment:example.tgz"
        if result == "" && ['source', 'attachment'].include?(type)
          result = "#{negator}#{type}:#{dest}"
        end

        # handle revisions/changesets like [123]
        if result == "" && dest =~ /^[0-9]+$/
          result = "#{negator}r#{dest}"
        end

        # default fall-through (for wiki: and unknown type links):
        if result == ""
          result = "#{negator}[[#{dest}#{text == '' ? '' : '|' + text}]]"
        end
        "#{result}"
      end

      # now other special-case links:
      # changeset:123 should become r123
      Oniguruma::ORegexp.new('(?<!!)changeset:([0-9]+)').gsub!(t, 'r\1')

      # ticket:123 should become #123
      Oniguruma::ORegexp.new('(?<!!)ticket:([0-9]+)').gsub!(t, '#\1')

      return t
    end
  end
end


if __FILE__ == $0
  f = RedmineTracFormatter::WikiFormatter.new

  infile = ARGV[0]
  expfile = ARGV[1]
  showdiff = ARGV.length > 2 ? true : false

  file = File.open("#{infile}", "rb")
  input = file.read
  f.text = input
  output = f.parse_trac_wiki

  outfile = '/tmp/test.output'
  File.open(outfile, 'w') {|f| f.write(output) }

  redirect = showdiff ? "" : " > /dev/null 2>&1"
  system "diff #{expfile} #{outfile} #{redirect}"
  if !showdiff && $? != 0
    puts "ERROR: #{infile}"
  end
  exit $?
end
