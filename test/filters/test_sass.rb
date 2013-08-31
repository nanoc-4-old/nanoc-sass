# encoding: utf-8

require 'helper'

class Nanoc::Sass::FilterTest < Minitest::Test

  def test_filter
    # Get filter
    filter = create_filter({ :foo => 'bar' })

    # Run filter
    result = filter.run(".foo #bar\n  color: #f00")
    assert_match(/.foo\s+#bar\s*\{\s*color:\s+(red|#f00);?\s*\}/, result)
  end

  def test_filter_with_params
    # Create filter
    filter = create_filter({ :foo => 'bar' })

    # Check with compact
    result = filter.run(".foo #bar\n  color: #f00", :style => 'compact')
    assert_match(/^\.foo #bar[\s]*\{[\s]*color:\s*(red|#f00);?[\s]*\}/m, result)

    # Check with compressed
    result = filter.run(".foo #bar\n  color: #f00", :style => 'compressed')
    assert_match(/^\.foo #bar[\s]*\{[\s]*color:\s*(red|#f00);?[\s]*\}/m, result)
  end

  def test_filter_error
    # Create filter
    filter = create_filter

    # Run filter
    raised = false
    begin
      filter.run('$*#&!@($')
    rescue Sass::SyntaxError => e
      assert_match ':1', e.backtrace[0]
      raised = true
    end
    assert raised
  end

  def test_filter_can_import_external_files
    # Create filter
    filter = create_filter

    # Create sample file
    File.open('moo.sass', 'w') { |io| io.write "body\n  color: red" }

    # Run filter
    filter.run('@import moo')
  end

  def test_filter_can_import_relative_files
    # Create filter
    filter = create_filter

    # Create sample file
    File.open('moo.sass', 'w') { |io| io.write %Q{@import subdir/relative} }
    FileUtils.mkdir_p("subdir")
    File.open('subdir/relative.sass', 'w') { |io| io.write "body\n  color: red" }

    # Run filter
    filter.run('@import moo')
  end

  def test_filter_will_skip_items_without_filename
    # Create filter
    filter = create_filter

    # Create sample file
    File.open('moo.sass', 'w') { |io| io.write "body\n  color: red" }

    # Run filter
    filter.run('@import moo')
  end

  def test_css_imports_work
    # Create filter
    filter = create_filter

    # Run filter
    filter.run('@import moo.css')
  end

  def test_recompile_includes
    in_tmp_dir do
      # Create two Sass files
      FileUtils.mkdir_p('content')
      File.open('content/a.sass', 'w') do |io|
        io.write('@import b.sass')
      end
      File.open('content/b.sass', 'w') do |io|
        io.write("p\n  color: red")
      end

      # Update rules
      File.write('nanoc.yaml', '{}')
      File.open('Rules', 'w') do |io|
        io.write "compile '/a.sass' do\n"
        io.write "  filter :sass\n"
        io.write "  write item.identifier.with_ext('css')\n"
        io.write "end\n"
        io.write "\n"
        io.write "compile '/b.sass' do\n"
        io.write "  filter :sass\n"
        io.write "end\n"
      end

      # Compile
      site = Nanoc::SiteLoader.new.load
      compiler = Nanoc::Compiler.new(site)
      compiler.run

      # Check
      assert Dir['output/*'].size == 1
      assert File.file?('output/a.css')
      refute File.file?('output/b.css')
      assert_match(/^p\s*\{\s*color:\s*red;?\s*\}/, File.read('output/a.css'))

      # Update included file
      File.open('content/b.sass', 'w') do |io|
        io.write("p\n  color: blue")
      end

      # Recompile
      site = Nanoc::SiteLoader.new.load
      compiler = Nanoc::Compiler.new(site)
      compiler.run

      # Recheck
      assert Dir['output/*'].size == 1
      assert File.file?('output/a.css')
      refute File.file?('output/b.css')
      assert_match(/^p\s*\{\s*color:\s*blue;?\s*\}/, File.read('output/a.css'))
    end
  end

  def test_recompile_includes_with_underscore_without_extension
    in_tmp_dir do
      # Create two Sass files
      FileUtils.mkdir_p('content')
      File.write('content/a.sass', '@import b')
      File.write('content/_b.sass', "p\n  color: red")

      # Update rules
      File.write('nanoc.yaml', '{}')
      File.open('Rules', 'w') do |io|
        io.write "compile '/a.sass' do\n"
        io.write "  filter :sass\n"
        io.write "  write item.identifier.with_ext('css')\n"
        io.write "end\n"
        io.write "\n"
        io.write "compile '/_b.sass' do\n"
        io.write "  filter :sass\n"
        io.write "end\n"
      end

      # Compile
      site = Nanoc::SiteLoader.new.load
      compiler = Nanoc::Compiler.new(site)
      compiler.run

      # Check
      assert Dir['output/*'].size == 1
      assert File.file?('output/a.css')
      refute File.file?('output/b.css')
      assert_match(/^p\s*\{\s*color:\s*red;?\s*\}/, File.read('output/a.css'))

      # Update included file
      File.open('content/_b.sass', 'w') do |io|
        io.write("p\n  color: blue")
      end

      # Recompile
      site = Nanoc::SiteLoader.new.load
      compiler = Nanoc::Compiler.new(site)
      compiler.run

      # Recheck
      assert Dir['output/*'].size == 1
      assert File.file?('output/a.css')
      refute File.file?('output/b.css')
      assert_match(/^p\s*\{\s*color:\s*blue;?\s*\}/, File.read('output/a.css'))
    end
  end

private

  def in_tmp_dir(&block)
    FileUtils.mkdir_p('xtmp')
    FileUtils.cd('xtmp', &block)
  ensure
    FileUtils.rm_rf('xtmp')
  end

  def create_filter(params={})
    FileUtils.mkdir_p('content')
    File.open('content/blah.sass', 'w') { |io| io.write('p\n  color: green')}

    item = Nanoc::Item.new(Nanoc::TextualContent.new('blah', File.absolute_path('content/blah.sass')), {}, '/blah.sass')

    items = [ item ]
    params = { :item => items[0], :items => items }.merge(params)
    ::Nanoc::Sass::Filter.new(params)
  end

end
