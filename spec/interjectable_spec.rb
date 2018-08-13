require 'spec_helper'

describe Interjectable do
  shared_examples_for "an interjectable class" do
    let(:instance) { klass.new }

    describe "#inject" do
      before do
        klass.inject(:some_dependency) { :service }
      end

      it "doesn't have #inject as an instance method" do
        expect { instance.inject(:some_dependency) { :service } }.to raise_error(NameError)
      end

      it "adds an instance method getter and setter" do
        instance.some_dependency = 'aaa'
        expect(instance.some_dependency).to eq('aaa')
      end

      it "lazy-loads the default block" do
        expect(instance.instance_variable_get("@some_dependency")).to be_nil
        expect(instance.some_dependency).to eq(:service)
        expect(instance.instance_variable_get("@some_dependency")).not_to be_nil
      end

      it "allows transitive dependencies (via instance_eval)" do
        klass.inject(:first_dependency) { second_dependency }
        klass.inject(:second_dependency) { :value }

        expect(instance.first_dependency).to eq(:value)
      end

      it "calls dependency block once, even with a falsy value" do
        count = 0;
        klass.inject(:some_falsy_dependency) { count += 1; nil }

        2.times { expect(instance.some_falsy_dependency).to be_nil }
        expect(count).to eq(1)
      end

      context "with a dependency on another class" do
        before do
          expect(defined?(SomeOtherClass)).to be_falsey

          klass.inject(:some_other_class) { SomeOtherClass.new }
        end

        it "does not need to load that class (can be stubbed away)" do
          instance.some_other_class = :fake_other_class

          expect(instance.some_other_class).to eq(:fake_other_class)
        end
      end
    end

    describe "#inject_static" do
      let(:other_instance) { klass.new }

      before do
        klass.inject_static(:static_dependency) { :some_value }
      end

      it "doesn't have #inject_static as an instance method" do
        expect { instance.inject_static(:static_dependency) { :some_value } }.to raise_error(NameError)
      end

      it "adds an instance method and setter" do
        instance.static_dependency = 'aaa'
        expect(instance.static_dependency).to eq('aaa')
      end

      it "shares a value across all instances of a class" do
        instance.static_dependency = 'bbb'
        expect(other_instance.static_dependency).to eq('bbb')
      end

      it "calls its dependency block once across all instances" do
        count = 0;
        klass.inject_static(:falsy_static_dependency) { count += 1; nil }

        expect(instance.falsy_static_dependency).to be_nil
        expect(other_instance.falsy_static_dependency).to be_nil

        expect(count).to eq(1)
      end

      it "clears class variable on subsequent calls to inject_static" do
        expect(instance.static_dependency).to eq(:some_value)
        klass.inject_static(:static_dependency) { :another_value }
        expect(instance.static_dependency).to eq(:another_value)
        expect(other_instance.static_dependency).to eq(:another_value)
      end

      context "with a subclas" do
        let(:subclass) { Class.new(klass) }
        let(:subclass_instance) { subclass.new }

        it "shares its values with its superclass" do
          instance.static_dependency = 'ccc'
          expect(subclass_instance.static_dependency).to eq('ccc')
        end
      end
    end
  end

  context "when extended" do
    let(:klass) { Class.new { extend Interjectable } }

    it_should_behave_like "an interjectable class"
  end

  context "when included" do
    let(:klass) { Class.new { include Interjectable } }

    it_should_behave_like "an interjectable class"
  end
end
