var request = require('supertest');
var should = require('should');
var testUtils = require("../testUtils");
request = request(testUtils.url);

describe('Empty Api test', function(){
	describe('Writing /i', function(){
		it('should bad request', function(done){
			request
			.get('/i')
			.expect(400)
			.end(function(err, res){
				if (err) return done(err);
				var ob = JSON.parse(res.text);
				ob.should.have.property('result', 'Missing parameter &quot;app_key&quot; or &quot;device_id&quot;');
				done()
			});
		});
	});
	describe('Reading /o', function(){
		it('should bad request', function(done){
			request
			.get('/o')
			.expect(400)
			.end(function(err, res){
				if (err) return done(err);
				var ob = JSON.parse(res.text);
				ob.should.have.property('result', 'Missing parameter &quot;api_key&quot;');
				done()
			});
		});
	});
});