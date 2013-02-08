require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

ActiveRecord::Schema.define(:version => 1) do
  create_table :dogs, :force => true do |t|
    t.string :breed
    t.string :other_breed
    t.string :color
    t.string :name
    t.integer :age
  end

  create_table :cats, :force => true do |t|
    t.string :breed
  end
end

class Breed < ClassyEnum::Base; end
class Breed::GoldenRetriever < Breed; end
class Breed::Snoop < Breed; end
class Breed::Husky < Breed; end

class Color < ClassyEnum::Base; end
class Color::White < Color; end;
class Color::Black < Color; end;

class CatBreed < ClassyEnum::Base
  owner :cat

  def breed_color
    "#{cat.color} #{self}"
  end
end

class CatBreed::Abyssian < CatBreed; end
class CatBreed::Bengal < CatBreed; end
class CatBreed::Birman < CatBreed; end
class CatBreed::Persian < CatBreed; end

class Dog < ActiveRecord::Base; end

class DefaultDog < Dog
  classy_enum_attr :breed
end

class AllowBlankBreedDog < Dog
  classy_enum_attr :breed, :allow_blank => true
end

class AllowNilBreedDog < Dog
  classy_enum_attr :breed, :allow_nil => true
end

class OtherDog < Dog
  classy_enum_attr :other_breed, :enum => 'Breed'
end

describe DefaultDog do
  specify { DefaultDog.new(:breed => nil).should_not be_valid }
  specify { DefaultDog.new(:breed => '').should_not be_valid }

  context "with valid breed options" do
    [:golden_retriever, 'golden_retriever', Breed::GoldenRetriever.new, Breed::GoldenRetriever].each do |option|
      subject { DefaultDog.new(:breed => option) }
      it { should be_valid }
      its(:breed) { should be_a(Breed::GoldenRetriever) }
      its('breed.allow_blank') { should be_false }

      it 'stores the enum as a valid string representation' do
        subject.save!
        subject.reload
        subject.breed.should be_a(Breed::GoldenRetriever)
      end
    end
  end

  context "with invalid breed options" do
    subject { DefaultDog.new(:breed => :fake_breed) }
    it { should_not be_valid }
    it { should have(1).error_on(:breed) }
  end
end

describe "A ClassyEnum that allows blanks" do
  specify { AllowBlankBreedDog.new(:breed => nil).should be_valid }
  specify { AllowBlankBreedDog.new(:breed => '').should be_valid }

  context "with valid breed options" do
    subject { AllowBlankBreedDog.new(:breed => :golden_retriever) }
    it { should be_valid }
    its('breed.allow_blank') { should be_true }
  end

  context "with invalid breed options" do
    subject { AllowBlankBreedDog.new(:breed => :fake_breed) }
    it { should_not be_valid }
    it { should have(1).error_on(:breed) }
  end
end

describe "A ClassyEnum that allows nils" do
  specify { AllowNilBreedDog.new(:breed => nil).should be_valid }
  specify { AllowNilBreedDog.new(:breed => '').should_not be_valid }

  context "with valid breed options" do
    subject { AllowNilBreedDog.new(:breed => :golden_retriever) }
    it { should be_valid }
    its('breed.allow_blank') { should be_true }
  end

  context "with invalid breed options" do
    subject { AllowNilBreedDog.new(:breed => :fake_breed) }
    it { should_not be_valid }
    it { should have(1).error_on(:breed) }
  end
end

describe "A ClassyEnum that has a different field name than the enum" do
  subject { OtherDog.new(:other_breed => :snoop) }
  its(:other_breed) { should be_a(Breed::Snoop) }
end

class ActiveDog < Dog
  classy_enum_attr :color
  validates_uniqueness_of :name, :scope => :color
  scope :goldens, where(:breed => 'golden_retriever')
end

describe ActiveDog do
  context 'uniqueness on name' do
    subject { ActiveDog.new(:name => 'Kitteh', :breed => :golden_retriever, :color => :black) }
    it { should be_valid }

    context 'with existing kitteh' do
      before do
        ActiveDog.create!(:name => 'Kitteh', :breed => :husky, :color => :black)
      end

      it { should have(1).error_on(:name) }
    end
  end

  context 'scopes' do
    let!(:golden) { ActiveDog.create!(:name => 'Sebastian', :breed => :golden_retriever, :color => :white) }
    let!(:husky) { ActiveDog.create!(:name => 'Sirius', :breed => :husky, :color => :black) }

    after { ActiveDog.destroy_all }

    it 'should know all dogs' do
      ActiveDog.all.should include(golden, husky)
    end

    it 'should have a working scope' do
      ActiveDog.goldens.should include(golden)
      ActiveDog.goldens.should_not include(husky)
    end
  end

end

class Cat < ActiveRecord::Base
end

class DefaultCat < Cat
  classy_enum_attr :breed, :enum => 'CatBreed'
  attr_accessor :color
  delegate :breed_color, :to => :breed
end

class OtherCat < Cat
  classy_enum_attr :breed, :enum => 'CatBreed', :serialize_as_json => true
  attr_accessor :color
  delegate :breed_color, :to => :breed
end

describe DefaultCat do
  let(:abyssian) { DefaultCat.new(:breed => :abyssian, :color => 'black') }
  let(:persian) { OtherCat.new(:breed => :persian, :color => 'white') }

  it 'should delegate breed color to breed with an ownership reference' do
    abyssian.breed_color { should eql('black Abyssian') }
    persian.breed_color { should eql('white Persian') }
  end
end
