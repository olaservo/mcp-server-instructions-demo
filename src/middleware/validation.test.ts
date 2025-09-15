import request from 'supertest';
import express from 'express';
import { validateTodoCreate, validateTodoUpdate, validateTodoId } from './validation';

const createTestApp = (middleware: any) => {
  const app = express();
  app.use(express.json());
  app.use(middleware);
  app.use((req, res) => res.status(200).json({ success: true }));
  return app;
};

describe('Validation Middleware', () => {
  describe('validateTodoCreate', () => {
    const app = createTestApp(validateTodoCreate);

    it('should pass with valid data', async () => {
      const response = await request(app)
        .post('/')
        .send({ title: 'Valid Title', description: 'Valid description' });

      expect(response.status).toBe(200);
    });

    it('should reject missing title', async () => {
      const response = await request(app)
        .post('/')
        .send({ description: 'Description without title' });

      expect(response.status).toBe(400);
      expect(response.body.error).toBe('Validation failed');
      expect(response.body.details).toContainEqual({
        field: 'title',
        message: 'Title is required'
      });
    });

    it('should reject empty title', async () => {
      const response = await request(app)
        .post('/')
        .send({ title: '   ' });

      expect(response.status).toBe(400);
      expect(response.body.details).toContainEqual({
        field: 'title',
        message: 'Title cannot be empty'
      });
    });

    it('should reject title with HTML tags', async () => {
      const response = await request(app)
        .post('/')
        .send({ title: '<script>alert("xss")</script>' });

      expect(response.status).toBe(400);
      expect(response.body.details).toContainEqual({
        field: 'title',
        message: 'Title cannot contain HTML tags'
      });
    });

    // MISSING TEST: Should verify description HTML validation works consistently with title

    it('should reject title over 100 characters', async () => {
      const longTitle = 'a'.repeat(101);
      const response = await request(app)
        .post('/')
        .send({ title: longTitle });

      expect(response.status).toBe(400);
      expect(response.body.details).toContainEqual({
        field: 'title',
        message: 'Title must be 100 characters or less'
      });
    });

    it('should reject description over 500 characters', async () => {
      const longDescription = 'a'.repeat(501);
      const response = await request(app)
        .post('/')
        .send({ title: 'Valid Title', description: longDescription });

      expect(response.status).toBe(400);
      expect(response.body.details).toContainEqual({
        field: 'description',
        message: 'Description must be 500 characters or less'
      });
    });

    it('should handle multiple validation errors', async () => {
      const response = await request(app)
        .post('/')
        .send({ title: '', description: 'a'.repeat(501) });

      expect(response.status).toBe(400);
      expect(response.body.details).toHaveLength(2);
    });
  });

  describe('validateTodoId', () => {
    const app = express();
    app.use('/:id', validateTodoId);
    app.use((req, res) => res.status(200).json({ success: true }));

    it('should pass with valid numeric ID', async () => {
      const response = await request(app).get('/123');
      expect(response.status).toBe(200);
    });

    it('should reject non-numeric ID', async () => {
      const response = await request(app).get('/abc');
      expect(response.status).toBe(400);
      expect(response.body.details).toContainEqual({
        field: 'id',
        message: 'ID must be a positive integer',
        value: 'abc'
      });
    });

    // MISSING TEST: Should test ID "0" edge case - currently no validation for this
  });
});
