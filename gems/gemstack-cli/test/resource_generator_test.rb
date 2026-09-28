# frozen_string_literal: true

require "test_helper"

class ResourceSpecTest < Minitest::Test
  Spec = GemStack::CLI::ResourceSpec

  def test_names
    spec = Spec.new("line_items", ["name"])

    assert_equal %w[LineItem line_item line_items LineItems line-items lineItems lineItem],
                 [spec.class_name, spec.file_name, spec.plural, spec.plural_class, spec.url_segment,
                  spec.client_name, spec.variable]
  end

  def test_fields
    spec = Spec.new("Product", %w[name price:decimal notes:text:optional sku:string:unique category:references
                                  active:boolean])
    by_name = spec.fields.to_h { |f| [f.name, f] }

    assert_equal "string", by_name["name"].type
    assert_predicate by_name["name"], :required?
    refute_predicate by_name["notes"], :required?
    refute_predicate by_name["active"], :required?
    assert by_name["sku"].unique
    assert_equal "category_id", by_name["category"].column
    assert by_name["category"].index
  end

  def test_invalid_input
    assert_raises(Thor::Error) { Spec.new("Product", ["price:money"]) }
    assert_raises(Thor::Error) { Spec.new("Product", ["price:decimal:big"]) }
    assert_raises(Thor::Error) { Spec.new("Product", %w[name name:text]) }
    assert_raises(Thor::Error) { Spec.new("Admin::Product", ["name"]) }
    assert_raises(Thor::Error) { Spec.new("Product", ["name"], actions: %w[index publish]) }
  end
end

class ResourceGeneratorTest < Minitest::Test
  FIELDS = %w[name price:decimal description:text:optional sku:string:unique category:references active:boolean
              released_on:date:optional].freeze

  def setup
    @root = Dir.mktmpdir
    FileUtils.mkdir_p("#{@root}/config")
    File.write("#{@root}/config/routes.rb", "GemStack.routes do\nend\n")
    @out = StringIO.new
  end

  def teardown
    FileUtils.rm_rf(@root)
  end

  def generate(fields = FIELDS, name: "Product", actions: GemStack::CLI::ResourceSpec::REST_ACTIONS, **)
    spec = GemStack::CLI::ResourceSpec.new(name, fields, actions: actions)
    GemStack::CLI::ResourceGenerator.new(spec, root: @root, output: @out, timestamp: "20260928120000", **).run
  end

  def read(path) = File.read(File.join(@root, path))
  def files = Dir.glob("**/*", base: @root).reject { |f| File.directory?(File.join(@root, f)) }.sort

  def test_full_slice
    generate

    assert_equal %w[
      app/controllers/products_controller.rb app/models/product.rb app/serializers/product_serializer.rb
      config/routes.rb db/migrations/20260928120000_create_products.rb
      frontend/app/products/[id]/edit/page.tsx frontend/app/products/[id]/page.tsx frontend/app/products/new/page.tsx
      frontend/app/products/page.tsx frontend/components/products/ProductCard.tsx
      frontend/components/products/ProductForm.tsx frontend/components/products/ProductTable.tsx
      frontend/lib/format.ts frontend/lib/queries/products.ts
      test/controllers/products_controller_test.rb test/models/product_test.rb
    ], files
    assert_includes read("config/routes.rb"), "  resources :products\n"
  end

  def test_migration
    generate
    migration = read("db/migrations/20260928120000_create_products.rb")

    assert_includes migration, "create_table(:products) do"
    assert_includes migration, "String :name, null: false"
    assert_includes migration, "BigDecimal :price, size: [12, 2], null: false"
    assert_includes migration, "String :description, text: true\n"
    assert_includes migration, "String :sku, null: false, unique: true"
    assert_includes migration, "foreign_key :category_id, :categories, type: :Bignum, null: false, on_delete: :restrict"
    assert_includes migration, "TrueClass :active, null: false, default: false"
    assert_includes migration, "Date :released_on\n"
    assert_includes migration, "index :category_id"
    assert_includes migration, "column :created_at, :timestamptz, null: false"
  end

  def test_model_serializer_controller
    generate

    model = read("app/models/product.rb")

    assert_includes model, "field :name, :string, null: false, size: 255"
    assert_includes model, "field :description, :text\n"
    assert_includes model, "field :category_id, :references, null: false"
    assert_includes model, "field :active, :boolean, null: false, default: false"
    assert_includes model, "validates :sku, uniqueness: true"
    assert_includes model, "belongs_to :category"
    assert_includes read("app/serializers/product_serializer.rb"),
                    "attributes :id, :name, :price, :description, :sku, :category_id, :active, :released_on, :created_at, :updated_at"
    controller = read("app/controllers/products_controller.rb")

    assert_includes controller, "accepts :create, with: Product.input_schema"
    assert_includes controller, "accepts :update, with: Product.input_schema, partial: true"
    assert_includes controller, "render Product.create(input), status: :created"
    assert_includes controller, "head :no_content"
  end

  def test_generated_ruby_is_valid_syntax
    generate
    Dir.glob("**/*.rb", base: @root).each do |file|
      assert system(RbConfig.ruby, "-c", File.join(@root, file), out: File::NULL), "#{file} has a syntax error"
    end
  end

  def test_tests_use_sample_data
    generate
    test = read("test/controllers/products_controller_test.rb")

    assert_includes test, "GemStack::DB::Testing.sample_payload(Product)"
    assert_includes test, %(assert_error 422, "validation_failed")
    assert_includes test, %(assert_equal ["is required"], json_body["errors"]["name"])
    assert_includes read("test/models/product_test.rb"), "def test_requires_category_id"
  end

  def test_frontend_form
    generate
    form = read("frontend/components/products/ProductForm.tsx")

    assert_includes form, "import type { Product, ProductInput } from \"@/lib/api/generated\";"
    assert_includes form, "price: record?.price ?? \"\","
    assert_includes form, "category_id: String(record?.category_id ?? \"\"),"
    assert_includes form, "active: record?.active ?? false,"
    assert_includes form, "description: values.description === \"\" ? null : values.description,"
    assert_includes form, "category_id: values.category_id === \"\" ? \"\" : Number(values.category_id),"
    assert_includes form,
                    %(<input id="price" name="price" type="text" inputMode="decimal" value={values.price} onChange={set("price")} required />)
    assert_includes form,
                    %(<input id="active" name="active" type="checkbox" checked={values.active} onChange={set("active")} />)
    refute_includes form, "<%"
  end

  def test_read_only_resource
    generate(%w[name], actions: %w[index show])

    assert_includes read("config/routes.rb"), "resources :products, only: %i[index show]"
    refute File.exist?(File.join(@root, "frontend/app/products/new/page.tsx"))
    refute File.exist?(File.join(@root, "frontend/components/products/ProductForm.tsx"))
    refute_includes read("app/controllers/products_controller.rb"), "accepts"
    refute_includes read("frontend/lib/queries/products.ts"), "useCreateProduct"
  end

  def test_api_only_and_frontend_only_parts
    generate(parts: %i[migration model serializer controller])

    refute Dir.exist?(File.join(@root, "frontend"))
    FileUtils.rm_rf(Dir.glob("#{@root}/{app,db,test}"))
    generate(parts: %i[frontend])

    refute Dir.exist?(File.join(@root, "app"))
    assert File.exist?(File.join(@root, "frontend/app/products/page.tsx"))
  end

  def test_skip_tests
    generate(tests: false)

    refute Dir.exist?(File.join(@root, "test"))
  end

  def test_routes_are_not_duplicated_and_files_not_overwritten
    generate
    File.write(File.join(@root, "app/models/product.rb"), "# mine\n")
    generate

    assert_equal 1, read("config/routes.rb").scan("resources :products").size
    assert_equal "# mine\n", read("app/models/product.rb")
  end

  def test_template_override
    custom = File.join(@root, "lib/templates/gemstack/resource/model/app/models/%file_name%.rb.tt")
    FileUtils.mkdir_p(File.dirname(custom))
    File.write(custom, "# custom <%= class_name %>\n")
    generate

    assert_equal "# custom Product\n", read("app/models/product.rb")
  end
end

class MigrationGeneratorTest < Minitest::Test
  def test_add_columns
    Dir.mktmpdir do |root|
      GemStack::CLI::MigrationGenerator.new("AddSkuToProducts", %w[sku:string:unique weight:decimal:optional],
                                            root: root, output: StringIO.new, timestamp: "20260101000000").run
      migration = File.read(File.join(root, "db/migrations/20260101000000_add_sku_to_products.rb"))

      assert_includes migration, "alter_table(:products) do"
      assert_includes migration, "add_column :sku, String, null: false, unique: true"
      assert_includes migration, "add_column :weight, BigDecimal, size: [12, 2]"
      assert system(RbConfig.ruby, "-c", File.join(root, "db/migrations/20260101000000_add_sku_to_products.rb"),
                    out: File::NULL)
    end
  end

  def test_empty_migration
    Dir.mktmpdir do |root|
      GemStack::CLI::MigrationGenerator.new("BackfillPrices", [], root: root, output: StringIO.new,
                                                                  timestamp: "20260101000000").run

      assert_includes File.read(File.join(root, "db/migrations/20260101000000_backfill_prices.rb")), "# create_table"
    end
  end
end
