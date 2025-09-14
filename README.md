# MCP Server Instructions Demo

A minimal TypeScript Express API for demonstrating pull request reviews.

## Features

- CRUD operations for todos
- TypeScript for type safety
- In-memory data storage
- Input validation
- Jest testing
- ESLint & Prettier

## API Endpoints

- `GET /` - Health check
- `GET /api/todos` - Get all todos
- `GET /api/todos/:id` - Get todo by ID
- `POST /api/todos` - Create new todo
- `PUT /api/todos/:id` - Update todo
- `DELETE /api/todos/:id` - Delete todo

## Setup

```bash
npm install
npm run build
npm start
```

## Development

```bash
npm run dev
npm test
npm run lint
```

## Todo Structure

```typescript
{
  id: string;
  title: string;
  description?: string;
  completed: boolean;
  createdAt: Date;
  updatedAt: Date;
}
```
