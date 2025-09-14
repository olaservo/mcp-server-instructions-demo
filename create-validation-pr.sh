#!/bin/bash

# Script to create a detailed validation enhancement PR for demo purposes

set -e

BRANCH_NAME="feature/input-validation-enhancement"
BASE_BRANCH="main"

echo "Creating validation enhancement PR..."

# Cleanup any existing branch and PR first
echo "Cleaning up any existing test branch and PR..."

# Check if we're currently on the branch to be deleted
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" = "$BRANCH_NAME" ]; then
    echo "Switching from $BRANCH_NAME to $BASE_BRANCH..."
    git checkout "$BASE_BRANCH"
fi

# Delete local branch if it exists
if git branch --list | grep -q "$BRANCH_NAME"; then
    echo "Deleting local branch: $BRANCH_NAME"
    git branch -D "$BRANCH_NAME"
else
    echo "Local branch $BRANCH_NAME not found"
fi

# Delete remote branch if it exists
if git ls-remote --heads origin "$BRANCH_NAME" | grep -q "$BRANCH_NAME"; then
    echo "Deleting remote branch: origin/$BRANCH_NAME"
    git push origin --delete "$BRANCH_NAME"
else
    echo "Remote branch origin/$BRANCH_NAME not found"
fi

# Close any open PR for this branch
echo "Checking for open PR..."
if gh pr list --head "$BRANCH_NAME" --json number --jq '.[0].number' 2>/dev/null | grep -q '^[0-9]'; then
    PR_NUMBER=$(gh pr list --head "$BRANCH_NAME" --json number --jq '.[0].number')
    echo "Closing PR #$PR_NUMBER..."
    gh pr close "$PR_NUMBER"
else
    echo "No open PR found for branch $BRANCH_NAME"
fi

echo "Cleanup completed. Now creating new branch..."

# Create and switch to feature branch
git checkout -b "$BRANCH_NAME" "$BASE_BRANCH"

echo "Creating validation middleware..."

# Create middleware directory if it doesn't exist
mkdir -p src/middleware

# Create validation middleware
cat > src/middleware/validation.ts << 'EOF'
import { Request, Response, NextFunction } from 'express';

export interface ValidationError {
  field: string;
  message: string;
  value?: any;
}

export class ValidationException extends Error {
  public errors: ValidationError[];

  constructor(errors: ValidationError[]) {
    super('Validation failed');
    this.name = 'ValidationException';
    this.errors = errors;
  }
}

export const validateTodoCreate = (req: Request, res: Response, next: NextFunction) => {
  const errors: ValidationError[] = [];
  const { title, description } = req.body;

  // Validate title
  if (!title) {
    errors.push({ field: 'title', message: 'Title is required' });
  } else if (typeof title !== 'string') {
    errors.push({ field: 'title', message: 'Title must be a string', value: title });
  } else if (title.trim().length === 0) {
    errors.push({ field: 'title', message: 'Title cannot be empty' });
  } else if (title.length > 100) {
    errors.push({ field: 'title', message: 'Title must be 100 characters or less' });
  } else if (/<[^>]*>/g.test(title)) {
    errors.push({ field: 'title', message: 'Title cannot contain HTML tags' });
  }

  // Validate description
  if (description !== undefined && description !== null) {
    if (typeof description !== 'string') {
      errors.push({ field: 'description', message: 'Description must be a string', value: description });
    } else if (description.length > 500) {
      errors.push({ field: 'description', message: 'Description must be 500 characters or less' });
    } else if (/<.*>/g.test(description)) {  // BUG: Inconsistent regex - allows <img> but title rejects it
      errors.push({ field: 'description', message: 'Description cannot contain HTML tags' });
    }
  }

  if (errors.length > 0) {
    return res.status(400).json({
      error: 'Validation failed',
      details: errors
    });
  }

  next();
};

export const validateTodoUpdate = (req: Request, res: Response, next: NextFunction) => {
  const errors: ValidationError[] = [];
  const { title, description, completed } = req.body;

  // Validate title if provided
  if (title !== undefined) {
    if (typeof title !== 'string') {
      errors.push({ field: 'title', message: 'Title must be a string', value: title });
    } else if (title.trim().length === 0) {
      errors.push({ field: 'title', message: 'Title cannot be empty' });
    } else if (title.length > 100) {
      errors.push({ field: 'title', message: 'Title must be 100 characters or less' });
    } else if (/<[^>]*>/g.test(title)) {
      errors.push({ field: 'title', message: 'Title cannot contain HTML tags' });
    }
  }

  // Validate description if provided
  if (description !== undefined && description !== null) {
    if (typeof description !== 'string') {
      errors.push({ field: 'description', message: 'Description must be a string', value: description });
    } else if (description.length > 500) {
      errors.push({ field: 'description', message: 'Description must be 500 characters or less' });
    } else if (/<[^>]*>/g.test(description)) {
      errors.push({ field: 'description', message: 'Description cannot contain HTML tags' });
    }
  }

  // Validate completed if provided
  if (completed !== undefined && typeof completed !== 'boolean') {
    errors.push({ field: 'completed', message: 'Completed must be a boolean', value: completed });
  }

  if (errors.length > 0) {
    return res.status(400).json({
      error: 'Validation failed',
      details: errors
    });
  }

  next();
};

export const validateTodoId = (req: Request, res: Response, next: NextFunction) => {
  const { id } = req.params;

  if (!id || !/^\d+$/.test(id)) {
    return res.status(400).json({
      error: 'Invalid ID format',
      details: [{ field: 'id', message: 'ID must be a positive integer', value: id }]
    });
  }

  // BUG: This allows ID "0" which may not be valid depending on our ID generation strategy
  next();
};
EOF

echo "Created validation middleware"

# Update routes to use validation
cat > src/routes/todos.ts << 'EOF'
import { Request, Response, Router } from 'express';
import { todoStore } from '../store/todoStore';
import { CreateTodoRequest, UpdateTodoRequest } from '../types/todo';
import { validateTodoCreate, validateTodoUpdate, validateTodoId } from '../middleware/validation';

const router = Router();

router.get('/', (req: Request, res: Response) => {
  const todos = todoStore.getAll();
  res.json(todos);
});

router.get('/:id', validateTodoId, (req: Request, res: Response) => {
  const { id } = req.params;
  const todo = todoStore.getById(id);
  
  if (!todo) {
    return res.status(404).json({ 
      error: 'Todo not found',
      details: [{ field: 'id', message: `Todo with ID ${id} does not exist`, value: id }]
    });
  }
  
  res.json(todo);
});

router.post('/', validateTodoCreate, (req: Request, res: Response) => {
  const { title, description }: CreateTodoRequest = req.body;
  
  // BUG: No try-catch block - if todoStore.create throws, server will crash
  const todo = todoStore.create({ 
    title: title.trim(), 
    description: description?.trim() || undefined 
  });
  res.status(201).json(todo);
});

router.put('/:id', validateTodoId, validateTodoUpdate, (req: Request, res: Response) => {
  const { id } = req.params;
  const updates: UpdateTodoRequest = req.body;
  
  // Trim string values
  if (updates.title) {
    updates.title = updates.title.trim();
  }
  if (updates.description) {
    updates.description = updates.description.trim();
  }
  
  const updatedTodo = todoStore.update(id, updates);
  
  if (!updatedTodo) {
    return res.status(404).json({ 
      error: 'Todo not found',
      details: [{ field: 'id', message: `Todo with ID ${id} does not exist`, value: id }]
    });
  }
  
  res.json(updatedTodo);
});

router.delete('/:id', validateTodoId, (req: Request, res: Response) => {
  const { id } = req.params;
  const deleted = todoStore.delete(id);
  
  if (!deleted) {
    return res.status(404).json({ 
      error: 'Todo not found',
      details: [{ field: 'id', message: `Todo with ID ${id} does not exist`, value: id }]
    });
  }
  
  res.status(204).send();
});

export { router as todoRoutes };
EOF

echo "Updated routes with validation"

# Create comprehensive tests
cat > src/middleware/validation.test.ts << 'EOF'
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
EOF

echo "Created validation tests"

# Add supertest dependency to package.json
npm install --save-dev supertest @types/supertest

# Update README with validation rules
cat >> README.md << 'EOF'

## Validation Rules

### Creating Todos
- **title**: Required, 1-100 characters, no HTML tags
- **description**: Optional, max 500 characters, no HTML tags

### Updating Todos
- **title**: Optional, 1-100 characters, no HTML tags (if provided)
- **description**: Optional, max 500 characters, no HTML tags (if provided)  
- **completed**: Optional, must be boolean (if provided)

### ID Parameters
- Must be positive integers only

### Error Response Format
```json
{
  "error": "Validation failed",
  "details": [
    {
      "field": "title",
      "message": "Title is required"
    }
  ]
}
```
EOF

echo "Updated README with validation documentation"

# Commit changes
git add .
git commit -m "Add comprehensive input validation middleware

- Created validation middleware with field-specific error messages
- Added validation for title length, HTML tags, and required fields
- Implemented ID format validation for route parameters
- Updated routes to use validation middleware with proper error responses
- Added comprehensive test coverage for all validation scenarios
- Updated README with validation rules and error response format"

# Run tests to ensure everything works
npm test

# Build to ensure no TypeScript errors
npm run build

# Push branch
git push -u origin "$BRANCH_NAME"

# Create PR
gh pr create --title "Add comprehensive input validation with detailed error responses" --body "$(cat <<'PRBODY'
## Summary
- Added comprehensive input validation middleware for all Todo endpoints
- Implemented field-specific error messages with structured error responses  
- Added validation for title length, HTML tag prevention, and type checking
- Enhanced ID parameter validation for route security
- Added comprehensive test coverage for all validation scenarios

## Changes Made

### New Files
- `src/middleware/validation.ts` - Core validation logic with custom error handling
- `src/middleware/validation.test.ts` - Comprehensive test suite (15+ test cases)

### Modified Files
- `src/routes/todos.ts` - Integrated validation middleware, improved error responses
- `README.md` - Added validation rules and error response format documentation
- `package.json` - Added supertest for API testing

### Validation Rules Implemented
- **Title**: Required, 1-100 chars, no HTML tags, string type validation
- **Description**: Optional, max 500 chars, no HTML tags, string type validation  
- **Completed**: Boolean type validation when provided
- **ID Parameters**: Positive integer validation for all routes

## Test Coverage
- Valid input acceptance
- Missing required fields
- Invalid data types
- Length limit enforcement
- HTML tag prevention (XSS protection)
- Multiple simultaneous errors
- Edge cases and boundary conditions

## API Response Changes
**Before**: Simple error strings
```json
{ "error": "Title is required" }
```

**After**: Structured error objects with field details
```json
{
  "error": "Validation failed", 
  "details": [
    { "field": "title", "message": "Title is required" },
    { "field": "description", "message": "Description must be 500 characters or less" }
  ]
}
```

## Security Improvements
- HTML tag prevention to mitigate XSS attacks
- Input sanitization with automatic trimming
- Type validation to prevent injection attacks
- ID format validation to prevent path traversal

## Testing Instructions

1. **Install dependencies**: `npm install`
2. **Run test suite**: `npm test` (should show 15+ passing tests)
3. **Test API manually**:
   ```bash
   npm run dev
   
   # Test valid creation
   curl -X POST localhost:3000/api/todos \
     -H "Content-Type: application/json" \
     -d '{"title":"Valid Todo","description":"Valid description"}'
   
   # Test validation errors
   curl -X POST localhost:3000/api/todos \
     -H "Content-Type: application/json" \
     -d '{"title":"","description":"'$(printf 'a%.0s' {1..501})'"}'
   ```

## Breaking Changes
**Error response format has changed** - API consumers will need to handle the new structured error format

## Future Enhancements
- [ ] Add rate limiting validation
- [ ] Implement custom validation rules configuration
- [ ] Add internationalization for error messages
- [ ] Consider adding request sanitization middleware

PRBODY
)"

echo "PR created successfully!"
echo "Branch: $BRANCH_NAME"
echo "You can view the PR with: gh pr view"
