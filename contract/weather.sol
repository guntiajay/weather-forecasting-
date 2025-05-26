
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title WeatherForecast
 * @dev A decentralized weather forecasting smart contract
 * @author WeatherSync Protocol
 */
contract WeatherForecast {
    
    // Struct to store weather data
    struct WeatherData {
        string location;
        int16 temperature; // Temperature in Celsius * 10 (to handle decimals)
        uint8 humidity; // Humidity percentage
        uint16 pressure; // Pressure in hPa
        uint8 windSpeed; // Wind speed in km/h
        string condition; // Weather condition description
        uint256 timestamp; // When the data was recorded
        address reporter; // Who reported this data
    }
    
    // Struct for weather forecast
    struct ForecastData {
        int16 highTemp;
        int16 lowTemp;
        string condition;
        uint8 precipitationChance;
        uint256 date; // Unix timestamp for the date
    }
    
    // Events
    event WeatherReported(
        string indexed location,
        int16 temperature,
        address indexed reporter,
        uint256 timestamp
    );
    
    event ForecastUpdated(
        string indexed location,
        uint256 indexed date,
        address indexed forecaster
    );
    
    event ReporterRegistered(address indexed reporter, string name);
    
    // State variables
    address public owner;
    uint256 public reporterCount;
    uint256 public constant FORECAST_DAYS = 5;
    uint256 public constant REWARD_AMOUNT = 0.001 ether;
    
    // Mappings
    mapping(string => WeatherData) public currentWeather;
    mapping(string => mapping(uint256 => ForecastData)) public forecasts;
    mapping(address => bool) public authorizedReporters;
    mapping(address => string) public reporterNames;
    mapping(address => uint256) public reporterRewards;
    mapping(string => uint256) public lastUpdateTime;
    
    // Arrays to track locations
    string[] public trackedLocations;
    mapping(string => bool) public locationExists;
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }
    
    modifier onlyAuthorizedReporter() {
        require(authorizedReporters[msg.sender], "Not an authorized reporter");
        _;
    }
    
    modifier validLocation(string memory _location) {
        require(bytes(_location).length > 0, "Location cannot be empty");
        _;
    }
    
    // Constructor
    constructor() {
        owner = msg.sender;
        authorizedReporters[msg.sender] = true;
        reporterNames[msg.sender] = "Contract Owner";
        reporterCount = 1;
    }
    
    /**
     * @dev Register a new weather reporter
     * @param _reporter Address of the reporter
     * @param _name Name of the reporter
     */
    function registerReporter(address _reporter, string memory _name) 
        external 
        onlyOwner 
    {
        require(!authorizedReporters[_reporter], "Reporter already registered");
        require(bytes(_name).length > 0, "Name cannot be empty");
        
        authorizedReporters[_reporter] = true;
        reporterNames[_reporter] = _name;
        reporterCount++;
        
        emit ReporterRegistered(_reporter, _name);
    }
    
    /**
     * @dev Report current weather for a location
     * @param _location Location name
     * @param _temperature Temperature in Celsius * 10
     * @param _humidity Humidity percentage
     * @param _pressure Pressure in hPa
     * @param _windSpeed Wind speed in km/h
     * @param _condition Weather condition
     */
    function reportWeather(
        string memory _location,
        int16 _temperature,
        uint8 _humidity,
        uint16 _pressure,
        uint8 _windSpeed,
        string memory _condition
    ) 
        external 
        onlyAuthorizedReporter 
        validLocation(_location)
    {
        require(_humidity <= 100, "Invalid humidity value");
        require(_pressure > 0, "Invalid pressure value");
        require(bytes(_condition).length > 0, "Condition cannot be empty");
        
        // Add location to tracked locations if new
        if (!locationExists[_location]) {
            trackedLocations.push(_location);
            locationExists[_location] = true;
        }
        
        currentWeather[_location] = WeatherData({
            location: _location,
            temperature: _temperature,
            humidity: _humidity,
            pressure: _pressure,
            windSpeed: _windSpeed,
            condition: _condition,
            timestamp: block.timestamp,
            reporter: msg.sender
        });
        
        lastUpdateTime[_location] = block.timestamp;
        
        // Reward the reporter
        reporterRewards[msg.sender] += REWARD_AMOUNT;
        
        emit WeatherReported(_location, _temperature, msg.sender, block.timestamp);
    }
    
    /**
     * @dev Update weather forecast for a location
     * @param _location Location name
     * @param _dayOffset Days from today (0-4)
     * @param _highTemp High temperature
     * @param _lowTemp Low temperature
     * @param _condition Weather condition
     * @param _precipitationChance Chance of precipitation (0-100)
     */
    function updateForecast(
        string memory _location,
        uint8 _dayOffset,
        int16 _highTemp,
        int16 _lowTemp,
        string memory _condition,
        uint8 _precipitationChance
    ) 
        external 
        onlyAuthorizedReporter 
        validLocation(_location)
    {
        require(_dayOffset < FORECAST_DAYS, "Invalid day offset");
        require(_highTemp >= _lowTemp, "High temp must be >= low temp");
        require(_precipitationChance <= 100, "Invalid precipitation chance");
        require(bytes(_condition).length > 0, "Condition cannot be empty");
        
        uint256 targetDate = block.timestamp + (_dayOffset * 1 days);
        
        forecasts[_location][targetDate] = ForecastData({
            highTemp: _highTemp,
            lowTemp: _lowTemp,
            condition: _condition,
            precipitationChance: _precipitationChance,
            date: targetDate
        });
        
        emit ForecastUpdated(_location, targetDate, msg.sender);
    }
    
    /**
     * @dev Get current weather for a location
     * @param _location Location name
     * @return WeatherData struct
     */
    function getCurrentWeather(string memory _location) 
        external 
        view 
        returns (WeatherData memory) 
    {
        return currentWeather[_location];
    }
    
    /**
     * @dev Get forecast for a specific day
     * @param _location Location name
     * @param _dayOffset Days from today (0-4)
     * @return ForecastData struct
     */
    function getForecast(string memory _location, uint8 _dayOffset) 
        external 
        view 
        returns (ForecastData memory) 
    {
        require(_dayOffset < FORECAST_DAYS, "Invalid day offset");
        uint256 targetDate = block.timestamp + (_dayOffset * 1 days);
        return forecasts[_location][targetDate];
    }
    
    /**
     * @dev Get all tracked locations
     * @return Array of location names
     */
    function getTrackedLocations() external view returns (string[] memory) {
        return trackedLocations;
    }
    
    /**
     * @dev Get reporter information
     * @param _reporter Reporter address
     * @return name Reporter name
     * @return isAuthorized Whether reporter is authorized
     * @return rewards Total rewards earned
     */
    function getReporterInfo(address _reporter) 
        external 
        view 
        returns (string memory name, bool isAuthorized, uint256 rewards) 
    {
        return (
            reporterNames[_reporter],
            authorizedReporters[_reporter],
            reporterRewards[_reporter]
        );
    }
    
    /**
     * @dev Check if weather data is recent (within 1 hour)
     * @param _location Location name
     * @return bool Whether data is recent
     */
    function isWeatherDataRecent(string memory _location) 
        external 
        view 
        returns (bool) 
    {
        return (block.timestamp - lastUpdateTime[_location]) <= 3600; // 1 hour
    }
    
    /**
     * @dev Get weather data age in seconds
     * @param _location Location name
     * @return uint256 Age in seconds
     */
    function getWeatherDataAge(string memory _location) 
        external 
        view 
        returns (uint256) 
    {
        if (lastUpdateTime[_location] == 0) {
            return type(uint256).max; // Never updated
        }
        return block.timestamp - lastUpdateTime[_location];
    }
    
    /**
     * @dev Withdraw reporter rewards
     */
    function withdrawRewards() external {
        uint256 amount = reporterRewards[msg.sender];
        require(amount > 0, "No rewards to withdraw");
        require(address(this).balance >= amount, "Insufficient contract balance");
        
        reporterRewards[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }
    
    /**
     * @dev Fund the contract for reporter rewards
     */
    function fundContract() external payable onlyOwner {
        require(msg.value > 0, "Must send some ether");
    }
    
    /**
     * @dev Remove a reporter's authorization
     * @param _reporter Reporter address
     */
    function revokeReporter(address _reporter) external onlyOwner {
        require(authorizedReporters[_reporter], "Reporter not authorized");
        require(_reporter != owner, "Cannot revoke owner");
        
        authorizedReporters[_reporter] = false;
        reporterCount--;
    }
    
    /**
     * @dev Emergency function to withdraw contract balance
     */
    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
    
    /**
     * @dev Transfer ownership
     * @param _newOwner New owner address
     */
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid address");
        owner = _newOwner;
    }
    
    // Receive function to accept ether
    receive() external payable {}
}
