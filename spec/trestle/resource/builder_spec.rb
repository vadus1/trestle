require 'spec_helper'

describe Trestle::Resource::Builder do
  before(:each) do
    Object.send(:remove_const, :TestAdmin) if Object.const_defined?(:TestAdmin)
    stub_const("Trestle::ApplicationController", Class.new(ActionController::Base))
  end

  it "creates a top-level Resource subclass" do
    Trestle::Resource::Builder.create(:test)
    expect(::TestAdmin).to be < Trestle::Resource
  end

  it "creates an AdminController class" do
    Trestle::Resource::Builder.create(:test)
    expect(::TestAdmin::AdminController).to be < Trestle::Resource::Controller
    expect(::TestAdmin::AdminController.admin).to eq(::TestAdmin)
  end

  describe "#table" do
    it "builds an index table with the admin and sortable options set" do
      Trestle::Resource::Builder.create(:test) do
        table custom: "option" do
          column :test
        end
      end

      expect(::TestAdmin.tables[:index]).to be_a(Trestle::Table)
      expect(::TestAdmin.tables[:index].options).to eq(custom: "option", sortable: true, admin: ::TestAdmin)
      expect(::TestAdmin.tables[:index].columns[0].field).to eq(:test)
    end

    it "builds a named table with the admin option set" do
      Trestle::Resource::Builder.create(:test) do
        table :named, custom: "option" do
          column :test
        end
      end

      expect(::TestAdmin.tables[:named]).to be_a(Trestle::Table)
      expect(::TestAdmin.tables[:named].options).to eq(custom: "option", admin: ::TestAdmin)
      expect(::TestAdmin.tables[:named].columns[0].field).to eq(:test)
    end
  end

  describe "#adapter" do
    it "returns the admin's adapter instance" do
      adapter = nil

      Trestle::Resource::Builder.create(:test) do
        adapter = self.adapter
      end

      expect(adapter).to eq(::TestAdmin.adapter)
    end

    it "evaluates the given block in the context of the adapter" do
      Trestle::Resource::Builder.create(:test) do
        adapter do
          def custom_method
            "Custom"
          end
        end
      end

      expect(::TestAdmin.adapter.custom_method).to eq("Custom")
    end
  end

  describe "#adapter=" do
    it "sets the admin's adapter to an instance of the given class" do
      adapter = double
      CustomAdapter = double(new: adapter)

      Trestle::Resource::Builder.create(:test) do
        self.adapter = CustomAdapter
      end

      expect(::TestAdmin.adapter).to eq(adapter)
    end
  end

  describe "#remove_action" do
    it "removes the given action(s) from the resource" do
      Trestle::Resource::Builder.create(:test) do
        remove_action :edit, :update
      end

      expect(::TestAdmin.actions).to eq([:index, :show, :new, :create, :destroy])
      expect(::TestAdmin::AdminController).not_to respond_to(:edit)
      expect(::TestAdmin::AdminController).not_to respond_to(:update)
    end
  end

  describe "#collection" do
    it "sets an explicit collection block" do
      Trestle::Resource::Builder.create(:test) do
        collection do
          [1, 2, 3]
        end
      end

      expect(::TestAdmin.collection).to eq([1, 2, 3])
    end
  end

  describe "#find_instance" do
    it "sets an explicit instance block" do
      Trestle::Resource::Builder.create(:test) do
        find_instance do |params|
          params[:id]
        end
      end

      expect(::TestAdmin.find_instance(id: 123)).to eq(123)
    end

    it "is aliased as #instance" do
      Trestle::Resource::Builder.create(:test) do
        instance do |params|
          params[:id]
        end
      end

      expect(::TestAdmin.find_instance(id: 123)).to eq(123)
    end
  end

  describe "#build_instance" do
    it "sets an explicit build_instance block" do
      Trestle::Resource::Builder.create(:test) do
        build_instance do |params|
          params
        end
      end

      expect(::TestAdmin.build_instance({ name: "Test" })).to eq({ name: "Test" })
    end
  end

  describe "#update_instance" do
    it "sets an explicit update_instance block" do
      Trestle::Resource::Builder.create(:test) do
        update_instance do |instance, params|
          instance.update_attributes(params)
        end
      end

      instance = double
      expect(instance).to receive(:update_attributes).with(name: "Test")
      expect(::TestAdmin.update_instance(instance, name: "Test"))
    end
  end

  describe "#save_instance" do
    it "sets an explicit save_instance block" do
      repository = double

      Trestle::Resource::Builder.create(:test) do
        save_instance do |instance|
          repository.save(instance)
        end
      end

      instance = double
      expect(repository).to receive(:save).with(instance)
      expect(::TestAdmin.save_instance(instance))
    end
  end

  describe "#delete_instance" do
    it "sets an explicit delete_instance block" do
      repository = double
      instance = double

      Trestle::Resource::Builder.create(:test) do
        delete_instance do |instance|
          repository.delete(instance)
        end
      end

      expect(repository).to receive(:delete).with(instance)
      expect(::TestAdmin.delete_instance(instance))
    end
  end

  describe "#params" do
    it "sets an explicit permitted_params block" do
      Trestle::Resource::Builder.create(:test) do
        params do |params|
          params.require(:test).permit(:name)
        end
      end

      params = ActionController::Parameters.new({ test: { name: "Test", ignored: 123 }})
      expect(::TestAdmin.permitted_params(params)).to eq(ActionController::Parameters.new(name: "Test").permit!)
    end
  end

  describe "#merge_scopes" do
    it "sets an explicit merge_scopes block" do
      Trestle::Resource::Builder.create(:test) do
        merge_scopes do |scope, other|
          scope.combine(other)
        end
      end

      collection = double
      other = double

      expect(collection).to receive(:combine).with(other).and_return([1, 2, 3])
      expect(::TestAdmin.merge_scopes(collection, other)).to eq([1, 2, 3])
    end
  end

  describe "#sort" do
    it "sets an explicit sort block" do
      Trestle::Resource::Builder.create(:test) do
        sort do |collection, field, order|
          collection.order(field => order)
        end
      end

      collection = double
      expect(collection).to receive(:order).with(name: :asc).and_return([1, 2, 3])
      expect(::TestAdmin.sort(collection, :name, :asc)).to eq([1, 2, 3])
    end
  end

  describe "#sort_column" do
    it "sets a column sort block" do
      Trestle::Resource::Builder.create(:test) do
        sort_column(:field) do |collection, order|
          collection.order(:field => order)
        end
      end

      collection = double
      allow(::TestAdmin).to receive(:initialize_collection).and_return(collection)

      expect(collection).to receive(:order).with(field: :asc).and_return([1, 2, 3])
      expect(::TestAdmin.prepare_collection(sort: "field", order: "asc")).to eq([1, 2, 3])
    end
  end

  describe "#paginate" do
    it "sets an explicit paginate block" do
      Trestle::Resource::Builder.create(:test) do
        paginate do |collection, params|
          collection.paginate(page: params[:page])
        end
      end

      collection = double
      expect(collection).to receive(:paginate).with(page: 5).and_return([1, 2, 3])
      expect(::TestAdmin.paginate(collection, page: 5)).to eq([1, 2, 3])
    end
  end

  describe "#count" do
    it "sets an explicit count block" do
      Trestle::Resource::Builder.create(:test) do
        count do |collection|
          collection.total_count
        end
      end

      collection = double(total_count: 123)
      expect(::TestAdmin.count(collection)).to eq(123)
    end
  end

  describe "#decorate_collection" do
    it "sets an explicit count block" do
      Trestle::Resource::Builder.create(:test) do
        decorate_collection do |collection|
          collection.decorate
        end
      end

      collection = double
      expect(collection).to receive(:decorate).and_return(collection)
      expect(::TestAdmin.decorate_collection(collection)).to eq(collection)
    end
  end

  describe "#decorator" do
    it "sets a decorator class" do
      class TestDecorator; end

      Trestle::Resource::Builder.create(:test) do
        decorator TestDecorator
      end

      collection = double
      expect(TestDecorator).to receive(:decorate_collection).with(collection).and_return([1, 2, 3])
      expect(::TestAdmin.decorate_collection(collection)).to eq([1, 2, 3])
    end
  end

  describe "#scope" do
    it "defines a scope on the admin" do
      b = Proc.new {}

      Trestle::Resource::Builder.create(:test) do
        scope :my_scope, label: "Custom Label", &b
      end

      expect(::TestAdmin.scopes).to include(my_scope: be_a(Trestle::Scope))
      expect(::TestAdmin.scopes[:my_scope].options).to eq(label: "Custom Label")
      expect(::TestAdmin.scopes[:my_scope].block).to eq(b)
    end

    context "with a proc as the second parameter" do
      it "uses the proc as the block" do
        b = Proc.new {}

        Trestle::Resource::Builder.create(:test) do
          scope :my_scope, b, label: "Custom Label"
        end

        expect(::TestAdmin.scopes).to include(my_scope: be_a(Trestle::Scope))
        expect(::TestAdmin.scopes[:my_scope].options).to eq(label: "Custom Label")
        expect(::TestAdmin.scopes[:my_scope].block).to eq(b)
      end
    end
  end

  describe "#return_to" do
    context "given options[:on]" do
      it "sets a return location block for the given action" do
        b = Proc.new {}

        Trestle::Resource::Builder.create(:test) do
          return_to on: :create, &b
        end

        expect(::TestAdmin.return_locations[:create]).to eq(b)
      end
    end

    context "without options[:on]" do
      it "sets the return location block for all actions" do
        b = Proc.new {}

        Trestle::Resource::Builder.create(:test) do
          return_to &b
        end

        expect(::TestAdmin.return_locations[:create]).to eq(b)
        expect(::TestAdmin.return_locations[:update]).to eq(b)
        expect(::TestAdmin.return_locations[:destroy]).to eq(b)
      end
    end
  end
end
