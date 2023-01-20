module Jekyll

    module Humanize  
      def filesize(value)
        ##
        # For filesize values in bytes, returns the number rounded to 3
        # decimal places with the correct suffix.
        #
        # Usage:
        # {{ bytes }} >>> 123456789
        # {{ bytes | filesize }} >>> 117.738 MB
        filesize_tb = 1099511627776.0
        filesize_gb = 1073741824.0
        filesize_mb = 1048576.0
        filesize_kb = 1024.0
  
        begin
          value = value.to_f
        rescue Exception => e
          puts "#{e.class} #{e}"
          return value
        end
  
        if value >= filesize_tb
          return "%s&thinsp;TB" % (value / filesize_tb).to_f.round(3)
        elsif value >= filesize_gb
          return "%s&thinsp;GB" % (value / filesize_gb).to_f.round(3)
        elsif value >= filesize_mb
          return "%s&thinsp;MB" % (value / filesize_mb).to_f.round(3)
        elsif value >= filesize_kb
          return "%s&thinsp;KB" % (value / filesize_kb).to_f.round(0)
        elsif value == 1
          return "1&thinsp;byte"
        else
          return "%s&thinsp;bytes" % value.to_f.round(0)
        end
  
      end
        
    end
  
end
  
Liquid::Template.register_filter(Jekyll::Humanize)
