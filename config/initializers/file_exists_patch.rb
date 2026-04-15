if File.respond_to?(:exist?) && !File.respond_to?(:exists?)
  class File
    def self.exists?(path)
      exist?(path)
    end
  end
end
