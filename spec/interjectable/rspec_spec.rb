# frozen_string_literal: true

require 'spec_helper'

describe "RSpec test helper #test_inject" do
  class Klass
    extend Interjectable
    inject(:dependency) { :dependency }
    inject_static(:static_dependency) { :static_dependency }

    define_method(:foo) { :foo }
  end
  SubKlass = Class.new(Klass)

  let(:instance) { Klass.new }
  let(:subklass_instance) { SubKlass.new }

  after(:all) do
    # Sanity check after running the tests, verify #test_inject cleans up after itself
    instance = Klass.new
    expect(instance.dependency).to eq(:dependency)
    expect(instance.static_dependency).to eq(:static_dependency)
    expect(Klass.static_dependency).to eq(:static_dependency)
    subklass_instance = SubKlass.new
    expect(subklass_instance.dependency).to eq(:dependency)
    expect(subklass_instance.static_dependency).to eq(:static_dependency)
    expect(SubKlass.static_dependency).to eq(:static_dependency)

    # Don't leak our test classes
    Object.instance_eval do
      remove_const(:SubKlass)
      remove_const(:Klass)
    end
  end

  context "isoloated context" do
    before(:all) do
      # Sanity check before running the tests
      instance = Klass.new
      expect(instance.dependency).to eq(:dependency)
      expect(instance.static_dependency).to eq(:static_dependency)
      expect(Klass.static_dependency).to eq(:static_dependency)
      subklass_instance = SubKlass.new
      expect(subklass_instance.dependency).to eq(:dependency)
      expect(subklass_instance.static_dependency).to eq(:static_dependency)
      expect(SubKlass.static_dependency).to eq(:static_dependency)

      Klass.test_inject(:dependency) { :unused_dependency }
      Klass.test_inject(:static_dependency) { :unused_overriden_static_dependency }
    end

    before do
      test_inject(Klass, :dependency, :another_unused_dependency)
      Klass.test_inject(:dependency) { foo }
      Klass.test_inject(:static_dependency) { :overriden_static_dependency }
    end

    it "sets the dependency" do
      expect(instance.dependency).to eq(:foo)
      expect(instance.static_dependency).to eq(:overriden_static_dependency)
      expect(Klass.static_dependency).to eq(:overriden_static_dependency)
    end

    it "still respects instance setters" do
      instance.dependency = :bar
      expect(instance.dependency).to eq(:bar)
    end

    it "errors if you inject a non static default into a static injection" do
      Klass.test_inject(:static_dependency) { foo }
      expect { instance.bad_dependency }.to raise_error(NameError)
      expect { Klass.bad_dependency }.to raise_error(NameError)
    end

    context "override dependency" do
      before(:all) do
        Klass.test_inject(:dependency) { :yet_another_unused_dependency }
        test_inject(Klass, :static_dependency, :unused_static_dependency)
      end

      before do
        Klass.test_inject(:dependency) { :override }
        Klass.test_inject(:static_dependency) { :double_overriden_static_dependency }
      end

      it "sets the dependency" do
        expect(instance.dependency).to eq(:override)
        expect(instance.static_dependency).to eq(:double_overriden_static_dependency)
        expect(Klass.static_dependency).to eq(:double_overriden_static_dependency)
      end

      it "sets the dependency again" do
        expect(instance.dependency).to eq(:override)
        expect(instance.static_dependency).to eq(:double_overriden_static_dependency)
        expect(Klass.static_dependency).to eq(:double_overriden_static_dependency)
      end

      context "in a subclass" do
        before do
          SubKlass.test_inject(:dependency) { :subklass_override }
          SubKlass.test_inject(:static_dependency) { :subklass_double_overriden_static_dependency }
        end

        it "sets the dependency" do
          expect(subklass_instance.dependency).to eq(:subklass_override)
          expect(subklass_instance.static_dependency).to eq(:subklass_double_overriden_static_dependency)
          expect(Klass.static_dependency).to eq(:double_overriden_static_dependency)
        end
      end

      context "in a context" do
        it "sets the dependency" do
          expect(instance.dependency).to eq(:override)
          expect(instance.static_dependency).to eq(:double_overriden_static_dependency)
          expect(Klass.static_dependency).to eq(:double_overriden_static_dependency)
        end

        it "sets the dependency again" do
          expect(instance.dependency).to eq(:override)
          expect(instance.static_dependency).to eq(:double_overriden_static_dependency)
          expect(Klass.static_dependency).to eq(:double_overriden_static_dependency)
        end
      end
    end
  end

  context "isoloated context: subclass inject" do
    before do
      SubKlass.test_inject(:dependency) { foo }
    end

    it "sets the dependency" do
      expect(subklass_instance.dependency).to eq(:foo)
    end

    context "subcontext" do
      it "sets the dependency" do
        expect(subklass_instance.dependency).to eq(:foo)
      end
    end
  end

  context "isoloated context: subclass before :all" do
    before(:all) do
      SubKlass.test_inject(:static_dependency) { :bar }
      SubKlass.test_inject(:static_dependency) { :zoo }
      test_inject(SubKlass, :static_dependency, :baz)
    end

    it "sets the static_dependency" do
      expect(SubKlass.static_dependency).to eq(:baz)
    end

    context "subcontext" do
      before(:all) do
        test_inject(SubKlass, :static_dependency, :goat)
      end

      it "sets the static_dependency" do
        expect(SubKlass.static_dependency).to eq(:goat)
      end
    end

    context "another subcontext" do
      it "sets the static_dependency" do
        expect(SubKlass.static_dependency).to eq(:baz)
      end
    end
  end

  context "rspec receive mocks" do
    before do
      instance_double(Object).tap do |fake_dependency|
        Klass.test_inject(:dependency) { fake_dependency }
      end
      instance_double(Object).tap do |fake_static_dependency|
        Klass.test_inject(:static_dependency) { fake_static_dependency }
      end
    end

    it "supports rspec mocks" do
      expect(instance.dependency).to receive(:to_s).and_return("house")
      expect(instance.dependency.to_s).to eq("house")
      expect(SubKlass.static_dependency).to receive(:to_s).and_return("boom")
      expect(SubKlass.static_dependency.to_s).to eq("boom")
      expect(subklass_instance.static_dependency).to receive(:to_s).and_return("not boom")
      expect(subklass_instance.static_dependency.to_s).to eq("not boom")
    end
  end

  describe "invalid arguments" do
    it "raises ArgumentError" do
      expect { Klass.test_inject(:dependency) }.to raise_error(ArgumentError)
      expect { Klass.test_inject { instance_double(Object) } }.to raise_error(ArgumentError)
      expect { Klass.test_inject(:bad_dependency) { 1 } }.to raise_error(ArgumentError)
    end
  end
end
