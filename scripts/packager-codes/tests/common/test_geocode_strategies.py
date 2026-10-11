from common.geocode_strategies import (
    strategy_split_street_comma,
    strategy_split_street_last_space,
    strategy_remove_street,
    strategy_split_city_hyphen,
    strategy_remove_city,
    strategy_remove_postalcode,
    create_strategy_reset_without_city,
    create_strategy_reset_without_country
)


def test_strategy_split_street_comma():
    """Test strategy: Remove text after comma in street"""
    params = {'street': 'Main St, Building A', 'city': 'Helsinki', 'postalcode': '00100'}
    
    result = strategy_split_street_comma("Finland", params, "FI 123 EC")
    
    assert result == {'street': 'Main St', 'city': 'Helsinki', 'postalcode': '00100'}


def test_strategy_split_street_comma_no_comma():
    """Test strategy when street has no comma"""
    params = {'street': 'Main St', 'city': 'Helsinki', 'postalcode': '00100'}
    
    result = strategy_split_street_comma("Finland", params, "FI 123 EC")
    
    assert result is None


def test_strategy_split_street_last_space():
    """Test strategy: Crop street after last number"""
    params = {'street': 'Landströmsgatan 21 Svartsmara', 'city': 'Helsinki'}
    
    result = strategy_split_street_last_space("Finland", params, "FI 123 EC")
    
    assert result == {'street': 'Landströmsgatan 21', 'city': 'Helsinki'}


def test_strategy_split_street_last_space_no_number():
    """Test strategy when street has no number"""
    params = {'street': 'Main Street', 'city': 'Helsinki'}
    
    result = strategy_split_street_last_space("Finland", params, "FI 123 EC")
    
    assert result is None


def test_strategy_remove_street():
    """Test strategy: Remove street entirely"""
    params = {'street': 'Main St', 'city': 'Helsinki', 'postalcode': '00100'}
    
    result = strategy_remove_street("Finland", params, "FI 123 EC")
    
    assert result == {'city': 'Helsinki', 'postalcode': '00100'}


def test_strategy_remove_street_already_removed():
    """Test strategy when street is already removed"""
    params = {'city': 'Helsinki', 'postalcode': '00100'}
    
    result = strategy_remove_street("Finland", params, "FI 123 EC")
    
    assert result is None


def test_strategy_remove_postalcode():
    """Test strategy: Remove postalcode"""
    params = {'street': 'Main St', 'city': 'Helsinki', 'postalcode': '00100'}
    
    result = strategy_remove_postalcode("Finland", params, "FI 123 EC")
    
    assert result == {'street': 'Main St', 'city': 'Helsinki'}


def test_strategy_split_city_hyphen():
    """Test strategy: Simplify city name before hyphen"""
    params = {'street': 'Main St', 'city': 'Aalborg-Øst', 'postalcode': '00100'}
    
    result = strategy_split_city_hyphen("Denmark", params, "DK 123 EF")
    
    assert result == {'street': 'Main St', 'city': 'Aalborg', 'postalcode': '00100'}


def test_strategy_split_city_hyphen_no_hyphen():
    """Test strategy when city has no hyphen"""
    params = {'street': 'Main St', 'city': 'Helsinki', 'postalcode': '00100'}
    
    result = strategy_split_city_hyphen("Finland", params, "FI 123 EC")
    
    assert result is None


def test_strategy_remove_city():
    """Test strategy: Remove city entirely"""
    params = {'street': 'Main St', 'city': 'Helsinki', 'postalcode': '00100'}
    
    result = strategy_remove_city("Finland", params, "FI 123 EC")
    
    assert result == {'street': 'Main St', 'postalcode': '00100'}


def test_create_strategy_reset_without_city():
    """Test factory: Create strategy to reset without city"""
    current_params = {'postalcode': '00100'}  # Simplified params
    initial_params = {
        'street': 'Main St',
        'city': 'Helsinki',
        'postalcode': '00100'
    }
    
    # Create the strategy
    strategy = create_strategy_reset_without_city(initial_params)
    result = strategy("Finland", current_params, "FI 123 EC")
    
    assert result == {'street': 'Main St', 'postalcode': '00100'}


def test_create_strategy_reset_without_country():
    """Test factory: Create strategy to reset without country"""
    current_params = {'city': 'Helsinki'}  # Simplified params
    initial_params = {
        'street': 'Main St, Building A',
        'city': 'Helsinki-City',
        'postalcode': '00100',
        'country': 'Finland',
        'countrycodes': 'fi'
    }
    
    # Create the strategy
    strategy = create_strategy_reset_without_country(initial_params)
    result = strategy("Finland", current_params, "FI 123 EC")
    
    assert result == {
        'street': 'Main St, Building A',
        'city': 'Helsinki-City',
        'postalcode': '00100'
    }


def test_strategy_preserves_other_params():
    """Test that strategies preserve parameters they don't modify"""
    params = {
        'street': 'Main St, Extra',
        'city': 'Helsinki-City',
        'postalcode': '00100',
        'country': 'Finland',
        'countrycodes': 'fi',
        'format': 'jsonv2',
        'custom': 'value'
    }
    
    # Test strategy_split_street_comma
    result = strategy_split_street_comma("Finland", params.copy(), "FI 123 EC")
    assert result['format'] == 'jsonv2'
    assert result['custom'] == 'value'
    
    # Test strategy_remove_postalcode
    result = strategy_remove_postalcode("Finland", params.copy(), "FI 123 EC")
    assert result['format'] == 'jsonv2'
    assert result['custom'] == 'value'


def test_strategies_return_new_dict():
    """Test that strategies return new dict and don't modify input"""
    original = {'street': 'Main St, Extra', 'city': 'Helsinki'}
    
    result = strategy_split_street_comma("Finland", original, "FI 123 EC")
    
    # Original should be unchanged
    assert original['street'] == 'Main St, Extra'
    # Result should be different
    assert result['street'] == 'Main St'
    assert result is not original
