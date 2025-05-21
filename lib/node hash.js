const bcrypt = require('bcrypt');
const password = 'admin'; // <-- set your new password here

bcrypt.hash(password, 10, function(err, hash) {
  if (err) throw err;
  console.log('Hash for password:', password);
  console.log(hash);
});
