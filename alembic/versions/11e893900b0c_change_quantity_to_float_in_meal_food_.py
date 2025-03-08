"""Change quantity to Float in meal_food_items

Revision ID: 11e893900b0c
Revises: 0a8e2ed30818
Create Date: 2025-02-16 05:10:43.917405

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '11e893900b0c'
down_revision: Union[str, None] = '0a8e2ed30818'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade():
    op.alter_column("meal_food_items", "quantity",
                    existing_type=sa.Integer(),
                    type_=sa.Float(),
                    existing_nullable=False)

def downgrade():
    op.alter_column("meal_food_items", "quantity",
                    existing_type=sa.Float(),
                    type_=sa.Integer(),
                    existing_nullable=False)