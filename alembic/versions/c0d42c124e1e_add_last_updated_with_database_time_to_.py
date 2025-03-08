"""Add last_updated with database time to food_items

Revision ID: c0d42c124e1e
Revises: 11e893900b0c
Create Date: 2025-02-24 04:36:20.800308

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'c0d42c124e1e'
down_revision: Union[str, None] = '11e893900b0c'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade():
    # Add last_updated column with database time
    op.add_column('food_items', sa.Column('last_updated', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False))

    # Update existing rows to set last_updated
    op.execute("UPDATE food_items SET last_updated = CURRENT_TIMESTAMP")

def downgrade():
    # Remove last_updated column
    op.drop_column('food_items', 'last_updated')