module CacheHelper
  def self.get_cache_path(url)
    uri = URI(url)
    cache_path = "cache" + uri.path

    # If the path doesn't have a common file extension, treat it as a directory.
    unless cache_path.match(/\.(html|xml|json|txt|js|css|jpg|jpeg|png|gif)$/i)
      cache_path += "/index.html"
    end

    cache_path
  end
end
