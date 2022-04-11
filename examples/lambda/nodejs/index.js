const moment = require('moment-timezone');

async function handler(event) {
  console.log(`EVENT ${JSON.stringify(event)}`);
  response = {time: moment.utc().format()};
  console.log(`EVENT ${JSON.stringify(response)}`);
  return response;
}

if (require.main === module) {
  handler({}).then(JSON.stringify).then(console.log);
} else {
  exports.handler = handler;
}
