import express from 'express';

const app = express();
app.use(express.json());

app.get('/', (req, res) => {
  res.send('Server is running');
});

app.post('/api/signup', (req, res) => {
  res.json({ message: 'Signup works', body: req.body });
});

app.listen(3002, () => {
  console.log('Test server running on port 3002');
});