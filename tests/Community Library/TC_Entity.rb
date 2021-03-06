require 'testup/testcase'
require_relative '../../tools/loader'

class TC_Entity < TestUp::TestCase

  LEntity = SkippyLib::LEntity

  def setup
    open_new_model
    
    model = Sketchup.active_model
    entities = model.entities
    
    @group = entities.add_group
    @group_definition = model.definitions.find { |d| d.instances.include?(@group) }
    @cpoint = @group.entities.add_cpoint(ORIGIN)
    @component_definition = model.definitions.add("Hejhopp")
    @component_definition.entities.add_cpoint(ORIGIN)
    @component_instance = entities.add_instance(@component_definition, IDENTITY)
  end

  def teardown
    discard_model_changes
  end

  #-----------------------------------------------------------------------------

  def test_component_definition
    assert_equal(@component_definition, LEntity.definition(@component_instance))

    assert_equal(@group_definition, LEntity.definition(@group))
  end

  def test_instance_Query
    msg = "A Group is an instance"
    assert(LEntity.instance?(@group), msg)

    msg = "A ComponentInstance is an instance"
    assert(LEntity.instance?(@component_instance), msg)

    msg = "A ComponentDefinition is not an instance"
    refute(LEntity.instance?(@component_definition), msg)

    msg = "A ConstructionPoint is not an instance"
    refute(LEntity.instance?(@cpoint), msg)
  end

end
