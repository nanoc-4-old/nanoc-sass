# encoding: utf-8

require 'sass'

module Nanoc::Sass

  class Filter < Nanoc::Filter

    class SassFilesystemImporter < ::Sass::Importers::Filesystem

      private

      def _find(dir, name, options)
        full_filename, syntax = ::Sass::Util.destructure(find_real_file(dir, name, options))
        return unless full_filename && File.readable?(full_filename)

        filter = options[:nanoc_current_filter]
        item = filter.imported_filename_to_item(full_filename)
        filter.depend_on([ item ]) unless item.nil?

        options[:syntax] = syntax
        options[:filename] = full_filename
        options[:importer] = self
        ::Sass::Engine.new(File.read(full_filename), options)
      end
    end

    identifier :sass

    def run(content, params={})
      # Build options
      options = params.dup
      sass_filename = item.content.filename
      # TODO check whether item.identifier exists
      options[:filename] ||= sass_filename
      options[:filesystem_importer] ||= Nanoc::Sass::Filter::SassFilesystemImporter

      # Find items
      item_dirglob = Pathname.new(sass_filename).dirname.realpath.to_s + '**'
      clean_items = @items.reject { |i| i.content.filename.nil? }
      @scoped_items, @rest_items = clean_items.partition do |i|
        i.content.filename && File.fnmatch(item_dirglob, i.content.filename)
      end

      # Render
      options[:nanoc_current_filter] = self
      engine = ::Sass::Engine.new(content, options)
      engine.render
    end

    def imported_filename_to_item(filename)
      filematch = lambda do |i|
        i.content.filename == File.absolute_path(filename)
      end
      @scoped_items.find(&filematch) || @rest_items.find(&filematch)
    end

  end

end
